import Foundation
import CoreMIDI

struct MIDISource: Identifiable, Hashable {
    let id: MIDIUniqueID
    let name: String
    let endpointRef: MIDIEndpointRef

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MIDISource, rhs: MIDISource) -> Bool {
        lhs.id == rhs.id
    }
}

/// Thread-safe box for the note callback, accessible from the CoreMIDI realtime thread.
private final class NoteCallback: @unchecked Sendable {
    private let lock = NSLock()
    private var _handler: ((UInt8, UInt8) -> Void)?

    var handler: ((UInt8, UInt8) -> Void)? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }
}

@MainActor
class MIDIService: ObservableObject {
    @Published var availableSources: [MIDISource] = []
    @Published var isConnected = false
    @Published var connectedSourceName: String?

    /// Set this to receive Note On events. Called on the main actor.
    var onNoteOn: ((UInt8, UInt8) -> Void)? {
        didSet {
            // Wrap the MainActor callback so CoreMIDI thread can invoke it safely
            if let callback = onNoteOn {
                noteCallback.handler = { note, channel in
                    Task { @MainActor in
                        callback(note, channel)
                    }
                }
            } else {
                noteCallback.handler = nil
            }
        }
    }

    private let noteCallback = NoteCallback()
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedEndpoint: MIDIEndpointRef = 0
    private var reconnectTimer: Timer?
    private var selectedSourceId: MIDIUniqueID?

    init() {
        setupClient()
        refreshSources()
    }

    private func setupClient() {
        let status = MIDIClientCreateWithBlock("CueLink" as CFString, &midiClient) { [weak self] notificationPtr in
            let messageID = notificationPtr.pointee.messageID
            if messageID == .msgSetupChanged {
                Task { @MainActor [weak self] in
                    self?.refreshSources()
                    self?.checkConnection()
                }
            }
        }
        if status != noErr {
            print("[CueLink] Failed to create MIDI client: \(status)")
        }
    }

    func refreshSources() {
        var sources: [MIDISource] = []
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let endpoint = MIDIGetSource(i)
            var uniqueID: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)

            var cfName: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &cfName)
            let name = (cfName?.takeRetainedValue() as String?) ?? "Unknown"

            sources.append(MIDISource(id: uniqueID, name: name, endpointRef: endpoint))
        }
        availableSources = sources

        // Reconnect if endpoint ref changed
        if let selectedId = selectedSourceId, isConnected {
            if let freshSource = sources.first(where: { $0.id == selectedId }) {
                if freshSource.endpointRef != connectedEndpoint {
                    connect(to: freshSource)
                }
            }
        }
    }

    func connect(to source: MIDISource) {
        // Disconnect existing
        if connectedEndpoint != 0 && inputPort != 0 {
            MIDIPortDisconnectSource(inputPort, connectedEndpoint)
            connectedEndpoint = 0
        }
        isConnected = false
        connectedSourceName = nil
        selectedSourceId = source.id

        // Re-resolve endpoint fresh from CoreMIDI
        var freshEndpoint: MIDIEndpointRef = source.endpointRef
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let ep = MIDIGetSource(i)
            var uid: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(ep, kMIDIPropertyUniqueID, &uid)
            if uid == source.id {
                freshEndpoint = ep
                break
            }
        }

        // Create input port if needed
        if inputPort == 0 {
            let portResult = MIDIService.createInputPort(
                client: midiClient,
                callback: noteCallback
            )
            if let port = portResult {
                inputPort = port
            } else {
                return
            }
        }

        let connectStatus = MIDIPortConnectSource(inputPort, freshEndpoint, nil)
        if connectStatus == noErr {
            connectedEndpoint = freshEndpoint
            isConnected = true
            connectedSourceName = source.name
            stopReconnectTimer()
            print("[CueLink] Connected to MIDI source: \(source.name)")
        } else {
            print("[CueLink] Failed to connect to source \(source.name): \(connectStatus)")
            startReconnectTimer()
        }
    }

    func disconnect() {
        if connectedEndpoint != 0 && inputPort != 0 {
            MIDIPortDisconnectSource(inputPort, connectedEndpoint)
            connectedEndpoint = 0
        }
        isConnected = false
        connectedSourceName = nil
        stopReconnectTimer()
    }

    /// Creates a MIDI input port outside of actor isolation so the callback doesn't inherit @MainActor.
    private nonisolated static func createInputPort(
        client: MIDIClientRef,
        callback: NoteCallback
    ) -> MIDIPortRef? {
        var port: MIDIPortRef = 0
        let status = MIDIInputPortCreateWithProtocol(
            client,
            "CueLinkInput" as CFString,
            ._1_0,
            &port
        ) { eventListPtr, _ in
            MIDIService.processEventList(eventListPtr, callback: callback)
        }
        if status != noErr {
            print("[CueLink] Failed to create MIDI input port: \(status)")
            return nil
        }
        return port
    }

    /// Static function — no actor isolation, safe to call from CoreMIDI's realtime thread.
    private nonisolated static func processEventList(_ eventListPtr: UnsafePointer<MIDIEventList>, callback: NoteCallback) {
        eventListPtr.unsafeSequence().forEach { packetPtr in
            let packet = packetPtr.pointee
            let wordCount = Int(packet.wordCount)
            guard wordCount > 0 else { return }

            withUnsafeBytes(of: packet.words) { rawBuffer in
                let words = rawBuffer.bindMemory(to: UInt32.self)
                var i = 0
                while i < wordCount {
                    let word = words[i]
                    let messageType = (word >> 28) & 0xF

                    if messageType == 0x2 {
                        // MIDI 1.0 Channel Voice Message (UMP)
                        let statusByte = UInt8((word >> 16) & 0xFF)
                        let statusNibble = statusByte & 0xF0
                        let channel = statusByte & 0x0F
                        let noteVal = UInt8((word >> 8) & 0xFF)
                        let velocity = UInt8(word & 0xFF)

                        if statusNibble == 0x90 && velocity > 0 {
                            callback.handler?(noteVal, channel)
                        }
                        i += 1
                    } else if messageType == 0x4 {
                        // MIDI 2.0 Channel Voice Message (2 words)
                        if i + 1 < wordCount {
                            let statusByte = UInt8((word >> 16) & 0xFF)
                            let statusNibble = statusByte & 0xF0
                            let noteVal = UInt8((word >> 8) & 0xFF)
                            let channel = statusByte & 0x0F
                            let velocity16 = UInt16(words[i + 1] >> 16)

                            if statusNibble == 0x90 && velocity16 > 0 {
                                callback.handler?(noteVal, channel)
                            }
                        }
                        i += 2
                    } else {
                        i += 1
                    }
                }
            }
        }
    }

    private func checkConnection() {
        guard let targetId = selectedSourceId else { return }
        if let source = availableSources.first(where: { $0.id == targetId }) {
            if !isConnected {
                connect(to: source)
            }
        } else {
            isConnected = false
            connectedSourceName = nil
            startReconnectTimer()
        }
    }

    private func startReconnectTimer() {
        guard reconnectTimer == nil else { return }
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSources()
                self?.checkConnection()
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}
