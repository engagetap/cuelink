import Foundation

enum WebhookError: Error {
    case invalidURL
    case invalidCustomPayload
}

struct WebhookResult {
    let url: String
    let statusCode: Int?
    let error: String?
    let responseBody: String?
    var isSuccess: Bool { statusCode != nil && (200..<300).contains(statusCode!) }
}

final class WebhookService: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func buildRequest(for mapping: CueLinkMapping) throws -> URLRequest {
        guard let url = URL(string: mapping.webhookURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebhookError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = mapping.httpMethod.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in mapping.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        switch mapping.payloadMode {
        case .default:
            request.httpBody = mapping.defaultPayloadJSON()
        case .custom:
            guard let customJSON = mapping.customPayload,
                  let data = customJSON.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                throw WebhookError.invalidCustomPayload
            }
            request.httpBody = data
        }

        return request
    }

    func fire(mapping: CueLinkMapping) async -> WebhookResult {
        let maxAttempts = max(1, mapping.retryCount + 1)
        var lastResult: WebhookResult?

        for attempt in 1...maxAttempts {
            let result = await fireSingle(mapping: mapping)
            lastResult = result
            if result.isSuccess {
                return result
            }
            // If we have more attempts, wait 1 second before retrying
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        return lastResult!
    }

    private func fireSingle(mapping: CueLinkMapping) async -> WebhookResult {
        do {
            let request = try buildRequest(for: mapping)
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            let isSuccess = statusCode != nil && (200..<300).contains(statusCode!)
            let bodySnippet: String? = isSuccess ? nil : responseBodySnippet(data)
            return WebhookResult(
                url: mapping.webhookURL,
                statusCode: statusCode,
                error: nil,
                responseBody: bodySnippet
            )
        } catch {
            return WebhookResult(
                url: mapping.webhookURL,
                statusCode: nil,
                error: error.localizedDescription,
                responseBody: nil
            )
        }
    }

    private func responseBodySnippet(_ data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }
        if text.count <= 200 { return text }
        return String(text.prefix(200)) + "..."
    }
}
