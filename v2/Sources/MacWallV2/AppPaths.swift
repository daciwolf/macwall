import Foundation

enum AppPaths {
    static var rootDirectoryURL: URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return applicationSupportDirectory.appendingPathComponent("MacWallV2", isDirectory: true)
    }

    static var importedVideosDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("ImportedVideos", isDirectory: true)
    }

    static var generatedFramesDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("GeneratedFrames", isDirectory: true)
    }

    static var customAerialStateURL: URL {
        rootDirectoryURL.appendingPathComponent("CustomAerialState.json", isDirectory: false)
    }

    static func ensureDirectoriesExist() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: importedVideosDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: generatedFramesDirectoryURL, withIntermediateDirectories: true)
    }
}
