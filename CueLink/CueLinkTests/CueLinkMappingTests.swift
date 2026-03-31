import Testing
import Foundation
@testable import CueLink

@Test func mappingRoundTripsAsJSON() throws {
    let mapping = CueLinkMapping(
        name: "Start Stream",
        midiNote: 60,
        midiChannel: 1,
        webhookURL: "https://example.com/hook",
        payloadMode: .custom,
        customPayload: "{\"action\":\"start\"}",
        httpMethod: .post,
        headers: ["Authorization": "Bearer tok"],
        isEnabled: true
    )

    let data = try JSONEncoder().encode(mapping)
    let decoded = try JSONDecoder().decode(CueLinkMapping.self, from: data)

    #expect(decoded.name == "Start Stream")
    #expect(decoded.midiNote == 60)
    #expect(decoded.midiChannel == 1)
    #expect(decoded.webhookURL == "https://example.com/hook")
    #expect(decoded.payloadMode == .custom)
    #expect(decoded.customPayload == "{\"action\":\"start\"}")
    #expect(decoded.httpMethod == .post)
    #expect(decoded.headers["Authorization"] == "Bearer tok")
    #expect(decoded.isEnabled == true)
}

@Test func mappingRetryCountClampsToRange() throws {
    let mapping = CueLinkMapping(name: "Retry Test", webhookURL: "https://example.com", retryCount: 5)
    #expect(mapping.retryCount == 3) // clamped to max 3

    let mapping2 = CueLinkMapping(name: "Retry Test", webhookURL: "https://example.com", retryCount: -1)
    #expect(mapping2.retryCount == 0) // clamped to min 0

    let mapping3 = CueLinkMapping(name: "Retry Test", webhookURL: "https://example.com", retryCount: 2)
    #expect(mapping3.retryCount == 2) // valid value preserved
}

@Test func mappingRetryCountRoundTripsAsJSON() throws {
    let mapping = CueLinkMapping(name: "Retry", webhookURL: "https://example.com", retryCount: 2)
    let data = try JSONEncoder().encode(mapping)
    let decoded = try JSONDecoder().decode(CueLinkMapping.self, from: data)
    #expect(decoded.retryCount == 2)
}

@Test func mappingRetryCountDefaultsWhenMissingFromJSON() throws {
    // Simulate JSON that predates the retryCount field
    let json = """
    {"id":"\(UUID().uuidString)","name":"Old","midiNote":60,"midiChannel":0,"webhookURL":"https://example.com","payloadMode":"default","httpMethod":"POST","headers":{},"isEnabled":true}
    """
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(CueLinkMapping.self, from: data)
    #expect(decoded.retryCount == 0)
}

@Test func mappingDefaultPayloadGeneration() throws {
    let mapping = CueLinkMapping(
        name: "Scene Change",
        midiNote: 72,
        midiChannel: 0,
        webhookURL: "https://example.com/hook",
        payloadMode: .default
    )

    let payload = mapping.defaultPayloadJSON()
    let parsed = try JSONSerialization.jsonObject(with: payload) as! [String: Any]

    #expect(parsed["cue"] as? String == "Scene Change")
    #expect(parsed["note"] as? Int == 72)
    #expect(parsed["channel"] as? Int == 0)
    #expect(parsed["timestamp"] != nil)
}
