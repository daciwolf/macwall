import Foundation
import MacWallCore

struct WallpaperLibraryEntry: Identifiable, Equatable, Codable {
    enum Source: String, Codable {
        case bundled
        case imported
    }

    let manifest: WallpaperManifest
    let videoURL: URL?
    let previewImageURL: URL?
    let source: Source

    var id: String {
        manifest.id
    }

    var availableFilesForValidation: Set<String> {
        guard source == .imported else {
            return manifest.requiredPackageFiles
        }

        guard let packageDirectoryURL else {
            return []
        }

        let fileManager = FileManager.default
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: packageDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return Set(fileURLs.map(\.lastPathComponent))
    }

    private var packageDirectoryURL: URL? {
        videoURL?.deletingLastPathComponent() ?? previewImageURL?.deletingLastPathComponent()
    }
}
