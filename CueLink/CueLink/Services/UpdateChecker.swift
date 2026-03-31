import Foundation

@MainActor
class UpdateChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?

    private let currentVersion: String
    private let repoOwner = "engagetap"
    private let repoName = "cuelink"

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            if compareVersions(remoteVersion, isNewerThan: currentVersion) {
                latestVersion = remoteVersion
                if let htmlURL = json["html_url"] as? String {
                    downloadURL = URL(string: htmlURL)
                }
                updateAvailable = true
            }
        } catch {
            print("[CueLink] Update check failed: \(error)")
        }
    }

    private func compareVersions(_ remote: String, isNewerThan local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
