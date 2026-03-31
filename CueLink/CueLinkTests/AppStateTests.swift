import Testing
import Foundation
@testable import CueLink

@Test @MainActor func addMappingSavesToStore() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let store = MappingStore(fileURL: tempDir.appendingPathComponent("mappings.json"))

    let state = AppState(mappingStore: store)
    let mapping = CueLinkMapping(name: "Test", webhookURL: "https://example.com")
    state.addMapping(mapping)

    #expect(state.mappings.count == 1)
    #expect(store.load().count == 1)

    try? FileManager.default.removeItem(at: tempDir)
}

@Test @MainActor func deleteMappingRemovesAndSaves() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let store = MappingStore(fileURL: tempDir.appendingPathComponent("mappings.json"))

    let state = AppState(mappingStore: store)
    let mapping = CueLinkMapping(name: "ToDelete", webhookURL: "https://example.com")
    state.addMapping(mapping)
    state.deleteMapping(mapping.id)

    #expect(state.mappings.isEmpty)
    #expect(store.load().isEmpty)

    try? FileManager.default.removeItem(at: tempDir)
}

@Test @MainActor func logEntryCapIsFiveHundred() {
    let state = AppState()
    for i in 0..<510 {
        state.addLogEntry(direction: .midiIn, details: "Note \(i)", status: .unmatched)
    }
    #expect(state.logEntries.count == 500)
}

@Test @MainActor func clearLogRemovesAll() {
    let state = AppState()
    state.addLogEntry(direction: .midiIn, details: "Test", status: .success)
    state.clearLog()
    #expect(state.logEntries.isEmpty)
}
