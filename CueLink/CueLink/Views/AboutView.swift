import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("CueLink")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(appVersion)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("A ProPresenter companion for\nMIDI-triggered webhooks")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Link("GitHub Repository",
                 destination: URL(string: "https://github.com/engagetap/cuelink")!)
                .font(.callout)
        }
        .padding(32)
        .frame(width: 300)
    }
}
