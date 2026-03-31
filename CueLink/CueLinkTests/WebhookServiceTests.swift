import Testing
import Foundation
@testable import CueLink

@Test func buildRequestWithDefaultPayload() throws {
    let mapping = CueLinkMapping(
        name: "Test Cue",
        midiNote: 60,
        midiChannel: 1,
        webhookURL: "https://example.com/hook",
        payloadMode: .default,
        httpMethod: .post,
        headers: ["X-Custom": "value"]
    )

    let service = WebhookService()
    let request = try service.buildRequest(for: mapping)

    #expect(request.url?.absoluteString == "https://example.com/hook")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "X-Custom") == "value")
    #expect(request.httpBody != nil)

    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    #expect(body["cue"] as? String == "Test Cue")
    #expect(body["note"] as? Int == 60)
    #expect(body["channel"] as? Int == 1)
}

@Test func buildRequestWithCustomPayload() throws {
    let customJSON = "{\"action\": \"go\"}"
    let mapping = CueLinkMapping(
        name: "Custom",
        midiNote: 72,
        midiChannel: 0,
        webhookURL: "https://example.com/custom",
        payloadMode: .custom,
        customPayload: customJSON,
        httpMethod: .put
    )

    let service = WebhookService()
    let request = try service.buildRequest(for: mapping)

    #expect(request.httpMethod == "PUT")
    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    #expect(body["action"] as? String == "go")
}

@Test func webhookResultResponseBodyTracksValue() {
    let result = WebhookResult(url: "https://example.com", statusCode: 500, error: nil, responseBody: "Internal Server Error")
    #expect(result.responseBody == "Internal Server Error")
    #expect(!result.isSuccess)

    let successResult = WebhookResult(url: "https://example.com", statusCode: 200, error: nil, responseBody: nil)
    #expect(successResult.responseBody == nil)
    #expect(successResult.isSuccess)
}

@Test func buildRequestRejectsInvalidURL() {
    let mapping = CueLinkMapping(
        name: "Bad",
        webhookURL: "not a url"
    )

    let service = WebhookService()
    #expect(throws: WebhookError.self) {
        try service.buildRequest(for: mapping)
    }
}
