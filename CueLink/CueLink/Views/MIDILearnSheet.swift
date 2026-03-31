import SwiftUI

struct MIDILearnSheet: View {
    @EnvironmentObject var appState: AppState
    var mappingId: UUID
    var onDismiss: () -> Void

    @State private var angle: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("MIDI Learn")
                .font(.headline)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }

            Text("Play a MIDI note now...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !appState.midiService.isConnected {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("No MIDI device connected")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button("Cancel") {
                appState.cancelLearning()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(30)
        .frame(width: 260)
        .onReceive(appState.$isLearning) { isLearning in
            // When learning completes (note received), dismiss
            if !isLearning {
                onDismiss()
            }
        }
    }
}
