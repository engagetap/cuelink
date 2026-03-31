import SwiftUI
import Sparkle

struct MenuBarPopover: View {
    @EnvironmentObject var appState: AppState
    var openSettings: () -> Void
    var openAbout: () -> Void
    var updaterController: SPUStandardUpdaterController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CueLink")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(appState.midiService.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                if let name = appState.midiService.connectedSourceName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No MIDI device connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !appState.logEntries.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ForEach(appState.logEntries.prefix(3)) { entry in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(entry.status))
                                .frame(width: 6, height: 6)
                            Text(entry.details)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }

            Button(action: {
                updaterController.checkForUpdates(nil)
            }) {
                Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
            }

            Button(action: openAbout) {
                Label("About CueLink", systemImage: "info.circle")
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func statusColor(_ status: LogStatus) -> Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .unmatched: .gray
        }
    }
}
