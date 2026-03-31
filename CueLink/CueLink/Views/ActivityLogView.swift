import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.logEntries.isEmpty {
                Spacer()
                Text("No activity yet")
                    .foregroundStyle(.secondary)
                Text("MIDI events and webhook responses will appear here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                Table(appState.logEntries) {
                    TableColumn("") { entry in
                        Circle()
                            .fill(statusColor(entry.status))
                            .frame(width: 8, height: 8)
                    }
                    .width(20)

                    TableColumn("Time") { entry in
                        Text(formatTimestamp(entry.timestamp))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 90, max: 110)

                    TableColumn("Direction") { entry in
                        Text(entry.direction.rawValue)
                            .font(.caption)
                    }
                    .width(min: 70, max: 90)

                    TableColumn("Details") { entry in
                        Text(entry.details)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            Divider()

            HStack {
                Text("\(appState.logEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear Log") {
                    appState.clearLog()
                }
                .buttonStyle(.borderless)
                .disabled(appState.logEntries.isEmpty)
            }
            .padding(8)
        }
    }

    private func statusColor(_ status: LogStatus) -> Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .unmatched: .gray
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func formatTimestamp(_ date: Date) -> String {
        Self.timestampFormatter.string(from: date)
    }
}
