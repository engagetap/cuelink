import Foundation

class MappingStore {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let cueLinkDir = appSupport.appendingPathComponent("CueLink", isDirectory: true)
            try? FileManager.default.createDirectory(at: cueLinkDir, withIntermediateDirectories: true)
            self.fileURL = cueLinkDir.appendingPathComponent("mappings.json")
        }
    }

    func load() -> [CueLinkMapping] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([CueLinkMapping].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ mappings: [CueLinkMapping]) {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(mappings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save mappings: \(error)")
        }
    }
}
