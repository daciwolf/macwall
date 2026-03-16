import AppKit
import Foundation

enum CustomAerialServiceError: LocalizedError {
    case missingAerialManifest(String)
    case commandFailed(String)
    case invalidImageEncoding

    var errorDescription: String? {
        switch self {
        case let .missingAerialManifest(path):
            return "The Apple aerial manifest was not found at `\(path)`."
        case let .commandFailed(message):
            return message
        case .invalidImageEncoding:
            return "Failed to encode the custom aerial thumbnail."
        }
    }
}

@MainActor
final class CustomAerialService {
    struct InstalledAsset: Identifiable {
        var id: String { assetID }

        let assetID: String
        let title: String
        let videoURL: URL
        let thumbnailURL: URL
        let installedAt: Date
        let isActive: Bool
    }

    private struct PersistedState: Codable {
        var customAssetID: String?
        var managedAssets: [ManagedAssetRecord]
        var originalSystemWallpaperURL: String?

        init(
            customAssetID: String? = nil,
            managedAssets: [ManagedAssetRecord] = [],
            originalSystemWallpaperURL: String? = nil
        ) {
            self.customAssetID = customAssetID
            self.managedAssets = managedAssets
            self.originalSystemWallpaperURL = originalSystemWallpaperURL
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            customAssetID = try container.decodeIfPresent(String.self, forKey: .customAssetID)
            managedAssets = try container.decodeIfPresent([ManagedAssetRecord].self, forKey: .managedAssets) ?? []
            originalSystemWallpaperURL = try container.decodeIfPresent(String.self, forKey: .originalSystemWallpaperURL)
        }
    }

    private struct ManagedAssetRecord: Codable, Equatable {
        var assetID: String
        var title: String
        var videoURL: URL
        var thumbnailURL: URL
        var installedAt: Date
    }

    private enum Paths {
        static var aerialsDirectoryURL: URL {
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("com.apple.wallpaper", isDirectory: true)
                .appendingPathComponent("aerials", isDirectory: true)
        }

        static var manifestDirectoryURL: URL {
            aerialsDirectoryURL.appendingPathComponent("manifest", isDirectory: true)
        }

        static var entriesURL: URL {
            manifestDirectoryURL.appendingPathComponent("entries.json", isDirectory: false)
        }

        static var thumbnailsDirectoryURL: URL {
            aerialsDirectoryURL.appendingPathComponent("thumbnails", isDirectory: true)
        }

        static var videosDirectoryURL: URL {
            aerialsDirectoryURL.appendingPathComponent("videos", isDirectory: true)
        }

        static var manifestTarURL: URL {
            aerialsDirectoryURL.appendingPathComponent("manifest.tar", isDirectory: false)
        }
    }

    private enum Constants {
        static let macCategoryID = "8048287A-39E6-4093-87EC-B0DCE7CB4A29"
        static let macSubcategoryID = "989909D1-AEFC-4BE5-9249-ABFBA5CABED0"
        static let systemWallpaperDomain = "com.apple.wallpaper"
        static let systemWallpaperURLKey = "SystemWallpaperURL"
    }

    private let fileManager = FileManager.default
    private let manifestEditor = AerialManifestEditor(
        macCategoryID: Constants.macCategoryID,
        macSubcategoryID: Constants.macSubcategoryID
    )

    var canRestoreOriginalSystemWallpaper: Bool {
        guard let state = try? normalizedState() else {
            return false
        }

        return state.originalSystemWallpaperURL != nil
    }

    func install(
        videoURL: URL,
        title: String,
        preferredAssetID: String,
        thumbnailImage: CGImage,
        activate: Bool
    ) throws -> InstalledAsset {
        try AppPaths.ensureDirectoriesExist()
        try ensureAppleAerialDirectoriesExist()
        try ensureAerialManifestExists()

        var state = try normalizedState()
        if state.originalSystemWallpaperURL == nil {
            state.originalSystemWallpaperURL = try readCurrentSystemWallpaperURL()
        }

        let manifestData = try Data(contentsOf: Paths.entriesURL)
        let existingIDs = try manifestEditor.assetIDs(in: manifestData)
        let assetID = AerialAssetIdentity.uniqueAssetID(
            from: preferredAssetID.isEmpty ? title : preferredAssetID,
            existingIDs: existingIDs
        )

        let destinationVideoURL = Paths.videosDirectoryURL.appendingPathComponent("\(assetID).mov", isDirectory: false)
        let destinationThumbnailURL = Paths.thumbnailsDirectoryURL.appendingPathComponent("\(assetID).png", isDirectory: false)

        try backupCurrentState()

        do {
            try removeItemIfPresent(at: destinationVideoURL)
            try removeItemIfPresent(at: destinationThumbnailURL)
            try fileManager.copyItem(at: videoURL, to: destinationVideoURL)
            try writeThumbnailImage(thumbnailImage, to: destinationThumbnailURL)

            let updatedManifestData = try manifestEditor.appendAsset(
                to: manifestData,
                descriptor: AerialManifestEditor.AssetDescriptor(
                    assetID: assetID,
                    title: title,
                    videoURL: destinationVideoURL,
                    thumbnailURL: destinationThumbnailURL
                )
            )
            try updatedManifestData.write(to: Paths.entriesURL, options: .atomic)
            try rebuildManifestArchive()
        } catch {
            try? removeItemIfPresent(at: destinationVideoURL)
            try? removeItemIfPresent(at: destinationThumbnailURL)
            throw error
        }

        state.managedAssets.removeAll { record in
            record.assetID == assetID
        }

        let installedAt = Date()
        state.managedAssets.append(
            ManagedAssetRecord(
                assetID: assetID,
                title: title,
                videoURL: destinationVideoURL,
                thumbnailURL: destinationThumbnailURL,
                installedAt: installedAt
            )
        )

        if activate {
            try writeSystemWallpaperURL(destinationVideoURL.absoluteString)
            try restartWallpaperAgent()
        }

        try saveState(state)

        return InstalledAsset(
            assetID: assetID,
            title: title,
            videoURL: destinationVideoURL,
            thumbnailURL: destinationThumbnailURL,
            installedAt: installedAt,
            isActive: activate
        )
    }

    func installedAssets() throws -> [InstalledAsset] {
        let state = try normalizedState()
        let activeURLString = try readCurrentSystemWallpaperURL()

        return state.managedAssets
            .sorted { lhs, rhs in
                lhs.installedAt > rhs.installedAt
            }
            .map { record in
                InstalledAsset(
                    assetID: record.assetID,
                    title: record.title,
                    videoURL: record.videoURL,
                    thumbnailURL: record.thumbnailURL,
                    installedAt: record.installedAt,
                    isActive: record.videoURL.absoluteString == activeURLString
                )
            }
    }

    func currentSystemWallpaperURL() throws -> String? {
        try readCurrentSystemWallpaperURL()
    }

    func activateAsset(withID assetID: String) throws {
        let state = try normalizedState()
        guard let asset = state.managedAssets.first(where: { record in
            record.assetID == assetID
        }) else {
            return
        }

        try writeSystemWallpaperURL(asset.videoURL.absoluteString)
        try restartWallpaperAgent()
    }

    func removeAsset(withID assetID: String) throws {
        var state = try normalizedState()
        let activeURLString = try readCurrentSystemWallpaperURL()
        let removedAsset = state.managedAssets.first(where: { record in
            record.assetID == assetID
        })

        if fileManager.fileExists(atPath: Paths.entriesURL.path) {
            try backupCurrentState()
            let manifestData = try Data(contentsOf: Paths.entriesURL)
            let updatedManifestData = try manifestEditor.removeAsset(withID: assetID, from: manifestData)
            try updatedManifestData.write(to: Paths.entriesURL, options: .atomic)
            try rebuildManifestArchive()
        }

        state.managedAssets.removeAll { record in
            record.assetID == assetID
        }

        if let removedAsset, removedAsset.videoURL.absoluteString == activeURLString {
            try restoreOriginalSystemWallpaper(using: &state)
        }

        try? removeItemIfPresent(at: Paths.videosDirectoryURL.appendingPathComponent("\(assetID).mov", isDirectory: false))
        try? removeItemIfPresent(at: Paths.thumbnailsDirectoryURL.appendingPathComponent("\(assetID).png", isDirectory: false))
        try saveState(state)
    }

    func restoreOriginalSystemWallpaper() throws {
        var state = try normalizedState()
        try restoreOriginalSystemWallpaper(using: &state)
        try saveState(state)
    }

    private func restoreOriginalSystemWallpaper(using state: inout PersistedState) throws {
        if let originalSystemWallpaperURL = state.originalSystemWallpaperURL {
            try writeSystemWallpaperURL(originalSystemWallpaperURL)
        } else {
            try deleteSystemWallpaperURL()
        }

        try restartWallpaperAgent()
    }

    private func ensureAppleAerialDirectoriesExist() throws {
        try fileManager.createDirectory(at: Paths.aerialsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: Paths.manifestDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: Paths.thumbnailsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: Paths.videosDirectoryURL, withIntermediateDirectories: true)
    }

    private func ensureAerialManifestExists() throws {
        if fileManager.fileExists(atPath: Paths.entriesURL.path) {
            return
        }

        if fileManager.fileExists(atPath: Paths.manifestTarURL.path) {
            try runCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
                arguments: [
                    "-xf",
                    Paths.manifestTarURL.path,
                    "-C",
                    Paths.manifestDirectoryURL.path,
                ]
            )
        }

        guard fileManager.fileExists(atPath: Paths.entriesURL.path) else {
            throw CustomAerialServiceError.missingAerialManifest(Paths.entriesURL.path)
        }
    }

    private func writeThumbnailImage(_ cgImage: CGImage, to destinationURL: URL) throws {
        let imageRepresentation = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = imageRepresentation.representation(using: .png, properties: [:]) else {
            throw CustomAerialServiceError.invalidImageEncoding
        }

        try pngData.write(to: destinationURL, options: .atomic)
    }

    private func backupCurrentState() throws {
        let backupStamp = makeBackupStamp()

        if fileManager.fileExists(atPath: Paths.entriesURL.path) {
            let backupURL = Paths.manifestDirectoryURL
                .appendingPathComponent("entries.json.bak.\(backupStamp)", isDirectory: false)
            try fileManager.copyItem(at: Paths.entriesURL, to: backupURL)
        }

        if fileManager.fileExists(atPath: Paths.manifestTarURL.path) {
            let backupURL = Paths.aerialsDirectoryURL
                .appendingPathComponent("manifest.tar.bak.\(backupStamp)", isDirectory: false)
            try fileManager.copyItem(at: Paths.manifestTarURL, to: backupURL)
        }
    }

    private func rebuildManifestArchive() throws {
        try runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
            arguments: [
                "-cf",
                Paths.manifestTarURL.path,
                "-C",
                Paths.manifestDirectoryURL.path,
                "entries.json",
                "TVIdleScreenStrings.bundle",
            ]
        )
    }

    private func writeSystemWallpaperURL(_ urlString: String) throws {
        try runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/defaults"),
            arguments: [
                "write",
                Constants.systemWallpaperDomain,
                Constants.systemWallpaperURLKey,
                "-string",
                urlString,
            ]
        )
    }

    private func deleteSystemWallpaperURL() throws {
        try runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/defaults"),
            arguments: [
                "delete",
                Constants.systemWallpaperDomain,
                Constants.systemWallpaperURLKey,
            ],
            allowsNonZeroExit: true
        )
    }

    private func readCurrentSystemWallpaperURL() throws -> String? {
        let output = try runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/defaults"),
            arguments: [
                "read",
                Constants.systemWallpaperDomain,
                Constants.systemWallpaperURLKey,
            ],
            allowsNonZeroExit: true
        )

        return output.isEmpty ? nil : output
    }

    private func restartWallpaperAgent() throws {
        try runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/killall"),
            arguments: ["WallpaperAgent"],
            allowsNonZeroExit: true
        )
    }

    private func loadState() throws -> PersistedState {
        guard fileManager.fileExists(atPath: AppPaths.customAerialStateURL.path) else {
            return PersistedState()
        }

        let data = try Data(contentsOf: AppPaths.customAerialStateURL)
        return try JSONDecoder().decode(PersistedState.self, from: data)
    }

    private func normalizedState() throws -> PersistedState {
        var state = try loadState()
        let originalState = state

        if let legacyAssetID = state.customAssetID,
           state.managedAssets.contains(where: { record in
               record.assetID == legacyAssetID
           }) == false {
            let legacyVideoURL = Paths.videosDirectoryURL.appendingPathComponent("\(legacyAssetID).mov", isDirectory: false)
            let legacyThumbnailURL = Paths.thumbnailsDirectoryURL.appendingPathComponent("\(legacyAssetID).png", isDirectory: false)

            if fileManager.fileExists(atPath: legacyVideoURL.path) || fileManager.fileExists(atPath: legacyThumbnailURL.path) {
                state.managedAssets.append(
                    ManagedAssetRecord(
                        assetID: legacyAssetID,
                        title: legacyAssetID,
                        videoURL: legacyVideoURL,
                        thumbnailURL: legacyThumbnailURL,
                        installedAt: Date.distantPast
                    )
                )
            }
        }

        let manifestAssetIDs: Set<String>
        if fileManager.fileExists(atPath: Paths.entriesURL.path) {
            let manifestData = try Data(contentsOf: Paths.entriesURL)
            manifestAssetIDs = try manifestEditor.assetIDs(in: manifestData)
        } else {
            manifestAssetIDs = []
        }

        state.customAssetID = nil
        state.managedAssets.removeAll { record in
            let videoExists = fileManager.fileExists(atPath: record.videoURL.path)
            let thumbnailExists = fileManager.fileExists(atPath: record.thumbnailURL.path)
            let manifestContainsAsset = manifestAssetIDs.isEmpty || manifestAssetIDs.contains(record.assetID)
            return !videoExists || !thumbnailExists || !manifestContainsAsset
        }

        if state.managedAssets != originalState.managedAssets || state.customAssetID != originalState.customAssetID {
            try saveState(state)
        }

        return state
    }

    private func saveState(_ state: PersistedState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: AppPaths.customAerialStateURL, options: .atomic)
    }

    private func removeItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func makeBackupStamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmssSSS"
        return formatter.string(from: Date())
    }

    @discardableResult
    private func runCommand(
        executableURL: URL,
        arguments: [String],
        allowsNonZeroExit: Bool = false
    ) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0, !allowsNonZeroExit {
            let argumentsDescription = ([executableURL.path] + arguments).joined(separator: " ")
            let message = errorOutput.isEmpty ? "Command failed: \(argumentsDescription)" : errorOutput
            throw CustomAerialServiceError.commandFailed(message)
        }

        return output
    }
}
