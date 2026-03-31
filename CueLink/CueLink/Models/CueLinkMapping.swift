import Foundation

enum PayloadMode: String, Codable, CaseIterable {
    case `default`
    case custom
}

enum WebhookHTTPMethod: String, Codable, CaseIterable {
    case post = "POST"
    case put = "PUT"
}

extension CueLinkMapping {
    func defaultPayloadJSON() -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload: [String: Any] = [
            "cue": name,
            "note": Int(midiNote),
            "channel": Int(midiChannel),
            "timestamp": formatter.string(from: Date())
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}

struct CueLinkMapping: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var midiNote: UInt8
    var midiChannel: UInt8
    var webhookURL: String
    var payloadMode: PayloadMode
    var customPayload: String?
    var httpMethod: WebhookHTTPMethod
    var headers: [String: String]
    var isEnabled: Bool
    var retryCount: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        midiNote: UInt8 = 60,
        midiChannel: UInt8 = 0,
        webhookURL: String = "",
        payloadMode: PayloadMode = .default,
        customPayload: String? = nil,
        httpMethod: WebhookHTTPMethod = .post,
        headers: [String: String] = [:],
        isEnabled: Bool = true,
        retryCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.midiNote = midiNote
        self.midiChannel = midiChannel
        self.webhookURL = webhookURL
        self.payloadMode = payloadMode
        self.customPayload = customPayload
        self.httpMethod = httpMethod
        self.headers = headers
        self.isEnabled = isEnabled
        self.retryCount = min(max(retryCount, 0), 3)
    }

    // Support decoding files that predate the retryCount field
    enum CodingKeys: String, CodingKey {
        case id, name, midiNote, midiChannel, webhookURL, payloadMode,
             customPayload, httpMethod, headers, isEnabled, retryCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        midiNote = try container.decode(UInt8.self, forKey: .midiNote)
        midiChannel = try container.decode(UInt8.self, forKey: .midiChannel)
        webhookURL = try container.decode(String.self, forKey: .webhookURL)
        payloadMode = try container.decode(PayloadMode.self, forKey: .payloadMode)
        customPayload = try container.decodeIfPresent(String.self, forKey: .customPayload)
        httpMethod = try container.decode(WebhookHTTPMethod.self, forKey: .httpMethod)
        headers = try container.decode([String: String].self, forKey: .headers)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
    }
}
