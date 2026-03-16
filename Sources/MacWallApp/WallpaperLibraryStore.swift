import Foundation

struct WallpaperLibraryStore: Sendable {
    private let rootDirectoryURL: URL

    init(rootDirectoryURL: URL? = nil) {
        let fileManager = FileManager.default

        if let rootDirectoryURL {
            self.rootDirectoryURL = rootDirectoryURL
        } else {
            let applicationSupportDirectory = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

            self.rootDirectoryURL = applicationSupportDirectory
                .appendingPathComponent("MacWall", isDirectory: true)
        }
    }

    var importedWallpapersDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("ImportedWallpapers", isDirectory: true)
    }

    var sharedStateURL: URL {
        rootDirectoryURL.appendingPathComponent("shared-state.json")
    }

    var powerLogURL: URL {
        rootDirectoryURL.appendingPathComponent("power-log.csv")
    }

    var lockScreenAerialStateURL: URL {
        rootDirectoryURL.appendingPathComponent("lock-screen-aerial-state.json")
    }

    var screenSaverPhotosDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("ScreenSaverPhotos", isDirectory: true)
    }

    private var libraryIndexURL: URL {
        rootDirectoryURL.appendingPathComponent("library.json")
    }

    func loadImportedEntries() throws -> [WallpaperLibraryEntry] {
        try loadJSONIfPresent([WallpaperLibraryEntry].self, from: libraryIndexURL) ?? []
    }

    func saveImportedEntries(_ entries: [WallpaperLibraryEntry]) throws {
        try saveJSON(entries, to: libraryIndexURL) { encoder in
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
    }

    func loadSharedState() throws -> MacWallSharedState? {
        try loadJSONIfPresent(MacWallSharedState.self, from: sharedStateURL) { decoder in
            decoder.dateDecodingStrategy = .iso8601
        }
    }

    func saveSharedState(_ sharedState: MacWallSharedState) throws {
        try saveJSON(sharedState, to: sharedStateURL) { encoder in
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
    }

    func appendPowerLogRow(_ row: String, header: String) throws {
        let fileManager = FileManager.default
        try ensureDirectoriesExist()

        if !fileManager.fileExists(atPath: powerLogURL.path()) {
            try Data((header + "\n").utf8).write(to: powerLogURL, options: .atomic)
        }

        let fileHandle = try FileHandle(forWritingTo: powerLogURL)
        defer {
            try? fileHandle.close()
        }

        try fileHandle.seekToEnd()
        try fileHandle.write(contentsOf: Data((row + "\n").utf8))
    }

    func makeImportDirectory() throws -> URL {
        let fileManager = FileManager.default
        try ensureDirectoriesExist()
        let importDirectory = importedWallpapersDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        return importDirectory
    }

    private func ensureDirectoriesExist() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: importedWallpapersDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: screenSaverPhotosDirectoryURL, withIntermediateDirectories: true)
    }

    private func loadJSONIfPresent<T: Decodable>(_ type: T.Type, from fileURL: URL) throws -> T? {
        try loadJSONIfPresent(type, from: fileURL) { _ in }
    }

    private func loadJSONIfPresent<T: Decodable>(
        _ type: T.Type,
        from fileURL: URL,
        configure: (JSONDecoder) -> Void
    ) throws -> T? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path()) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        configure(decoder)
        return try decoder.decode(type, from: data)
    }

    private func saveJSON<T: Encodable>(
        _ value: T,
        to fileURL: URL,
        configure: (JSONEncoder) -> Void = { _ in }
    ) throws {
        try ensureDirectoriesExist()
        let encoder = JSONEncoder()
        configure(encoder)
        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: .atomic)
    }
}
