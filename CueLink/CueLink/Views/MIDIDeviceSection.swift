import SwiftUI
import CoreMIDI

struct MIDIDeviceSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("MIDI Input Device") {
                Picker("Device", selection: Binding(
                    get: { appState.selectedMIDISourceId },
                    set: { newId in
                        if newId == 0 {
                            appState.midiService.disconnect()
                            appState.selectedMIDISourceId = 0
                        } else if let source = appState.midiService.availableSources.first(where: { Int($0.id) == newId }) {
                            appState.selectAndConnect(source: source)
                        }
                    }
                )) {
                    Text("None").tag(0)
                    ForEach(appState.midiService.availableSources) { source in
                        Text(source.name).tag(Int(source.id))
                    }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(appState.midiService.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(appState.midiService.isConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(appState.midiService.isConnected ? .primary : .secondary)
                }

                Button("Refresh Devices") {
                    appState.midiService.refreshSources()
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                    .onChange(of: appState.launchAtLogin) { _, newValue in
                        appState.setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
