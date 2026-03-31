import Foundation
import SwiftUI
import CoreMIDI
import ServiceManagement
import UserNotifications

@MainActor
class AppState: ObservableObject {
    @Published var mappings: [CueLinkMapping] = []
    @Published var logEntries: [LogEntry] = []
    @Published var isLearning = false
    @Published var learningMappingId: UUID?

    let midiService: MIDIService
    let webhookService: WebhookService
    let mappingStore: MappingStore

    @AppStorage("selectedMIDISourceId") var selectedMIDISourceId: Int = 0
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    private let logCap = 500
    private var autoConnectTimer: Timer?

    init(
        mappingStore: MappingStore = MappingStore(),
        midiService: MIDIService = MIDIService(),
        webhookService: WebhookService = WebhookService()
    ) {
        self.mappingStore = mappingStore
        self.midiService = midiService
        self.webhookService = webhookService
        self.mappings = mappingStore.load()

        midiService.onNoteOn = { [weak self] note, channel in
            Task { @MainActor [weak self] in
                self?.handleNoteOn(note: note, channel: channel)
            }
        }

        // Auto-connect to previously selected MIDI device
        if selectedMIDISourceId != 0 {
            connectToSelectedDevice()
            // If device not available yet, retry every 3 seconds
            if !midiService.isConnected {
                startAutoConnectTimer()
            }
        }
    }

    // MARK: - Mappings

    func addMapping(_ mapping: CueLinkMapping) {
        mappings.append(mapping)
        mappingStore.save(mappings)
    }

    func updateMapping(_ mapping: CueLinkMapping) {
        if let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
            mappings[index] = mapping
            mappingStore.save(mappings)
        }
    }

    func deleteMapping(_ id: UUID) {
        mappings.removeAll { $0.id == id }
        mappingStore.save(mappings)
    }

    func duplicateMapping(_ id: UUID) {
        guard let original = mappings.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.name = "\(original.name) Copy"
        addMapping(copy)
    }

    // MARK: - MIDI Learn

    func startLearning(for mappingId: UUID) {
        isLearning = true
        learningMappingId = mappingId
    }

    func cancelLearning() {
        isLearning = false
        learningMappingId = nil
    }

    // MARK: - MIDI → Webhook

    private func handleNoteOn(note: UInt8, channel: UInt8) {
        if isLearning, let targetId = learningMappingId {
            if let index = mappings.firstIndex(where: { $0.id == targetId }) {
                mappings[index].midiNote = note
                mappings[index].midiChannel = channel
                mappingStore.save(mappings)
            }
            isLearning = false
            learningMappingId = nil
            return
        }

        let matchedMappings = mappings.filter { $0.isEnabled && $0.midiNote == note && $0.midiChannel == channel }

        if matchedMappings.isEmpty {
            addLogEntry(direction: .midiIn, details: "Note \(note) Ch \(channel + 1) (unmatched)", status: .unmatched)
            return
        }

        addLogEntry(direction: .midiIn, details: "Note \(note) Ch \(channel + 1)", status: .success)

        let service = webhookService
        for mapping in matchedMappings {
            Task {
                let result = await service.fire(mapping: mapping)
                await MainActor.run {
                    let status: LogStatus = result.isSuccess ? .success : .failure
                    var details: String
                    if let code = result.statusCode {
                        details = "\(result.url) → \(code)"
                    } else {
                        details = "\(result.url) → \(result.error ?? "Unknown error")"
                    }
                    if !result.isSuccess, let body = result.responseBody {
                        details += " | Body: \(body)"
                    }
                    self.addLogEntry(direction: .webhookOut, details: details, status: status)

                    if !result.isSuccess {
                        self.postFailureNotification(mappingName: mapping.name, error: result.error ?? "HTTP \(result.statusCode ?? 0)")
                    }
                }
            }
        }
    }

    // MARK: - Activity Log

    func addLogEntry(direction: LogDirection, details: String, status: LogStatus) {
        let entry = LogEntry(timestamp: Date(), direction: direction, details: details, status: status)
        logEntries.insert(entry, at: 0)
        if logEntries.count > logCap {
            logEntries = Array(logEntries.prefix(logCap))
        }
    }

    func clearLog() {
        logEntries.removeAll()
    }

    // MARK: - MIDI Connection

    func connectToSelectedDevice() {
        let targetId = MIDIUniqueID(selectedMIDISourceId)
        midiService.refreshSources()
        if let source = midiService.availableSources.first(where: { $0.id == targetId }) {
            midiService.connect(to: source)
            stopAutoConnectTimer()
        }
    }

    private func startAutoConnectTimer() {
        guard autoConnectTimer == nil else { return }
        autoConnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.connectToSelectedDevice()
                if self.midiService.isConnected {
                    self.stopAutoConnectTimer()
                }
            }
        }
    }

    private func stopAutoConnectTimer() {
        autoConnectTimer?.invalidate()
        autoConnectTimer = nil
    }

    // MARK: - Notifications

    private func postFailureNotification(mappingName: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "CueLink Webhook Failed"
        content.body = "\(mappingName.isEmpty ? "Untitled" : mappingName): \(error)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Mapping Reorder

    func moveMappings(from source: IndexSet, to destination: Int) {
        mappings.move(fromOffsets: source, toOffset: destination)
        mappingStore.save(mappings)
    }

    func selectAndConnect(source: MIDISource) {
        selectedMIDISourceId = Int(source.id)
        midiService.connect(to: source)
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[CueLink] Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
        }
    }
}
