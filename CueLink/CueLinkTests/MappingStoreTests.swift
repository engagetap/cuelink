import Testing
import Foundation
@testable import CueLink

@Test func storeRoundTrips() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let filePath = tempDir.appendingPathComponent("mappings.json")

    let store = MappingStore(fileURL: filePath)

    let mapping = CueLinkMapping(
        name: "Test",
        midiNote: 42,
        midiChannel: 3,
        webhookURL: "https://example.com/test"
    )

    store.save([mapping])
    let loaded = store.load()

    #expect(loaded.count == 1)
    #expect(loaded[0].name == "Test")
    #expect(loaded[0].midiNote == 42)
    #expect(loaded[0].midiChannel == 3)

    try FileManager.default.removeItem(at: tempDir)
}

@Test func storeReturnsEmptyWhenFileDoesNotExist() {
    let filePath = FileManager.default.temporaryDirectory
        .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        .appendingPathComponent("mappings.json")
    let store = MappingStore(fileURL: filePath)
    let loaded = store.load()
    #expect(loaded.isEmpty)
}
