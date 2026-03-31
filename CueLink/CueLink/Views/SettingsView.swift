import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            MIDIDeviceSection()
                .tabItem { Label("MIDI", systemImage: "pianokeys") }
                .environmentObject(appState)
            MappingsListView()
                .tabItem { Label("Mappings", systemImage: "list.bullet") }
                .environmentObject(appState)
            ActivityLogView()
                .tabItem { Label("Log", systemImage: "clock") }
                .environmentObject(appState)
        }
        .frame(width: 650, height: 450)
    }
}
