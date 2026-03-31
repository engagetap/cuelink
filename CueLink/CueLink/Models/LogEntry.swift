import Foundation

enum LogDirection: String {
    case midiIn = "MIDI In"
    case webhookOut = "Webhook Out"
}

enum LogStatus {
    case success
    case failure
    case unmatched
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let direction: LogDirection
    let details: String
    let status: LogStatus
}
