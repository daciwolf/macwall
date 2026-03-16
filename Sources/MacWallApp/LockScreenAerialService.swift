import AppKit
import AVFoundation
import Foundation

enum LockScreenAerialServiceError: LocalizedError {
    case missingVideo(String)
    case missingAerialManifest(String)
    case invalidPreviewImage(String)
    case invalidImageEncoding
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingVideo(title):
            return "`\(title)` does not have a local video file, so it cannot be installed for the lock screen."
        case let .missingAerialManifest(path):
            return "The Apple aerial manifest was not found at `\(path)`."
        case let .invalidPreviewImage(path):
            return "MacWall could not turn `\(path)` into a lock-screen thumbnail."
        case .invalidImageEncoding:
            return "MacWall could not encode the lock-screen thumbnail as PNG."
        case let .commandFailed(message):
            return message
        }
    }
}

@MainActor
final class LockScreenAerialService {
    static let didChangeNotification = Notification.Name("MacWall.lockScreenAerialServiceDidChange")

    static let shared = LockScreenAerialService(
        stateFileURL: WallpaperLibraryStore().lockScreenAerialStateURL
    )

    struct InstalledAsset {
        let wallpaperID: String
        let assetID: String
        let title: String
        let videoURL: URL
        let thumbnailURL: URL
    }

    struct ManagedAsset: Identifiable, Equatable {
        let id: String
        let title: String
        let videoURL: URL?
        let thumbnailURL: URL?
        let installedAt: Date?
        let wallpaperID: String?
        let isActive: Bool
        let isTrackedByState: Bool
    }

    private struct PersistedState: Codable, Equatable {
        var managedAssets: [ManagedAssetRecord]
        var originalSystemWallpaperURL: String?

        init(
            managedAssets: [ManagedAssetRecord] = [],
            originalSystemWallpaperURL: String? = nil
        ) {
            self.managedAssets = managedAssets
            self.originalSystemWallpaperURL = originalSystemWallpaperURL
        }
    }

    private struct ManagedAssetRecord: Codable, Equatable {
        let wallpaperID: String
        let assetID: String
        let title: String
        let videoURL: URL
        let thumbnailURL: URL
        let installedAt: Date
    }

    private struct ManifestAsset {
        let assetID: String
        let title: String
        let videoURL: URL?
        let thumbnailURL: URL?
        let shotID: String
    }

    private struct InstallSource {
        let wallpaperID: String
        let title: String
        let videoURL: URL
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
        static let thumbnailSize = CGSize(width: 3840, height: 2160)
    }

    private let fileManager = FileManager.default
    private let stateFileURL: URL
    private let manifestEditor = AerialManifestEditor(
        macCategoryID: Constants.macCategoryID,
        macSubcategoryID: Constants.macSubcategoryID
    )
    private var reapplyWorkItem: DispatchWorkItem?

    init(stateFileURL: URL) {
        self.stateFileURL = stateFileURL
    }

    var canRestoreOriginalSystemWallpaper: Bool {
        guard let state = try? normalizedState() else {
            return false
        }

        return state.originalSystemWallpaperURL != nil
    }

    func currentSystemWallpaperURL() throws -> String? {
        try readCurrentSystemWallpaperURL()
    }

    func reapply() {
        reapplyWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            do {
                try self.applyInternal()
            } catch {
                NSLog("MacWall lock-screen reapply failed: %@", String(describing: error))
            }
        }

        reapplyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func installedAssets() throws -> [ManagedAsset] {
        let state = try normalizedState()
        let assetsByID = Dictionary(
            uniqueKeysWithValues: state.managedAssets.map { ($0.assetID, $0) }
        )
        let activeURLString = try readCurrentSystemWallpaperURL()

        return try macWallManifestAssets()
            .map { asset in
                let trackedAsset = assetsByID[asset.assetID]
                return ManagedAsset(
                    id: asset.assetID,
                    title: asset.title,
                    videoURL: asset.videoURL,
                    thumbnailURL: asset.thumbnailURL,
                    installedAt: trackedAsset?.installedAt,
                    wallpaperID: trackedAsset?.wallpaperID,
                    isActive: asset.videoURL?.absoluteString == activeURLString,
                    isTrackedByState: trackedAsset != nil
                )
            }
            .sorted(by: compareManagedAssets)
    }

    func installWallpaper(for entry: WallpaperLibraryEntry, activate: Bool = true) throws -> InstalledAsset {
        guard let sourceVideoURL = entry.videoURL else {
            throw LockScreenAerialServiceError.missingVideo(entry.manifest.title)
        }

        return try applyInternal(
            source: InstallSource(
                wallpaperID: entry.id,
                title: entry.manifest.title,
                videoURL: sourceVideoURL
            ),
            activate: activate
        )
    }

    private func applyInternal() throws {
        guard let source = try preferredReapplySource() else {
            return
        }

        _ = try applyInternal(source: source, activate: true)
    }

    private func applyInternal(
        source: InstallSource,
        activate: Bool
    ) throws -> InstalledAsset {
        guard fileManager.fileExists(atPath: source.videoURL.path) else {
            throw LockScreenAerialServiceError.missingVideo(source.title)
        }

        try ensureAppleAerialDirectoriesExist()
        try ensureAerialManifestExists()

        var state = try normalizedState()
        if state.originalSystemWallpaperURL == nil {
            state.originalSystemWallpaperURL = try sanitizedOriginalWallpaperURL(
                try readCurrentSystemWallpaperURL()
            )
        }

        let manifestData = try Data(contentsOf: Paths.entriesURL)
        let existingIDs = try manifestEditor.assetIDs(in: manifestData)
        let assetID = resolveAssetID(
            wallpaperID: source.wallpaperID,
            state: state,
            existingIDs: existingIDs
        )
        let destinationVideoURL = Paths.videosDirectoryURL.appendingPathComponent("\(assetID).mov", isDirectory: false)
        let destinationThumbnailURL = Paths.thumbnailsDirectoryURL.appendingPathComponent("\(assetID).png", isDirectory: false)
        let shouldCopyVideo = source.videoURL.standardizedFileURL != destinationVideoURL.standardizedFileURL

        try backupCurrentState()

        do {
            if shouldCopyVideo {
                try removeItemIfPresent(at: destinationVideoURL)
                try fileManager.copyItem(at: source.videoURL, to: destinationVideoURL)
            }

            try removeItemIfPresent(at: destinationThumbnailURL)

            let thumbnailImage = try thumbnailImage(for: source)
            try writeThumbnailImage(thumbnailImage, to: destinationThumbnailURL)

            let updatedManifestData = try manifestEditor.appendAsset(
                to: manifestData,
                descriptor: .init(
                    assetID: assetID,
                    title: source.title,
                    videoURL: destinationVideoURL,
                    thumbnailURL: destinationThumbnailURL
                )
            )
            try updatedManifestData.write(to: Paths.entriesURL, options: .atomic)
            try rebuildManifestArchive()
        } catch {
            if shouldCopyVideo {
                try? removeItemIfPresent(at: destinationVideoURL)
            }
            try? removeItemIfPresent(at: destinationThumbnailURL)
            throw error
        }

        let installedAt = Date()
        state.managedAssets.removeAll { record in
            record.wallpaperID == source.wallpaperID || record.assetID == assetID
        }
        state.managedAssets.append(
            ManagedAssetRecord(
                wallpaperID: source.wallpaperID,
                assetID: assetID,
                title: source.title,
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
        notifyStateDidChange()

        return InstalledAsset(
            wallpaperID: source.wallpaperID,
            assetID: assetID,
            title: source.title,
            videoURL: destinationVideoURL,
            thumbnailURL: destinationThumbnailURL
        )
    }

    @discardableResult
    func removeAssets(withIDs assetIDs: [String]) throws -> Int {
        let assetIDs = Set(assetIDs)
        guard !assetIDs.isEmpty else {
            return 0
        }

        var state = try normalizedState()
        let assetsToRemove = try macWallManifestAssets().filter { asset in
            assetIDs.contains(asset.assetID)
        }
        guard !assetsToRemove.isEmpty else {
            return 0
        }

        let removedVideoURLStrings = Set(
            assetsToRemove.compactMap { asset in
                asset.videoURL?.absoluteString
            }
        )

        if fileManager.fileExists(atPath: Paths.entriesURL.path) {
            try backupCurrentState()
            var manifestData = try Data(contentsOf: Paths.entriesURL)
            for asset in assetsToRemove {
                manifestData = try manifestEditor.removeAsset(withID: asset.assetID, from: manifestData)
            }

            try manifestData.write(to: Paths.entriesURL, options: .atomic)
            try rebuildManifestArchive()
        }

        for asset in assetsToRemove {
            if let videoURL = asset.videoURL {
                try? removeItemIfPresent(at: videoURL)
            }

            if let thumbnailURL = asset.thumbnailURL {
                try? removeItemIfPresent(at: thumbnailURL)
            }
        }

        state.managedAssets.removeAll { record in
            assetIDs.contains(record.assetID) || removedVideoURLStrings.contains(record.videoURL.absoluteString)
        }

        let currentSystemWallpaperURL = try readCurrentSystemWallpaperURL()
        if let currentSystemWallpaperURL,
           removedVideoURLStrings.contains(currentSystemWallpaperURL) {
            if let originalSystemWallpaperURL = try sanitizedOriginalWallpaperURL(state.originalSystemWallpaperURL) {
                try writeSystemWallpaperURL(originalSystemWallpaperURL)
            } else {
                state.originalSystemWallpaperURL = nil
                try deleteSystemWallpaperURL()
            }
        }

        if let originalSystemWallpaperURL = state.originalSystemWallpaperURL,
           removedVideoURLStrings.contains(originalSystemWallpaperURL) {
            state.originalSystemWallpaperURL = nil
        }

        state.originalSystemWallpaperURL = try sanitizedOriginalWallpaperURL(state.originalSystemWallpaperURL)
        try saveState(state)
        try restartWallpaperAgent()
        notifyStateDidChange()
        return assetsToRemove.count
    }

    func restoreOriginalSystemWallpaper() throws {
        var state = try normalizedState()

        if let originalSystemWallpaperURL = try sanitizedOriginalWallpaperURL(state.originalSystemWallpaperURL) {
            try writeSystemWallpaperURL(originalSystemWallpaperURL)
        } else {
            state.originalSystemWallpaperURL = nil
            try saveState(state)
            try deleteSystemWallpaperURL()
        }

        try restartWallpaperAgent()
        notifyStateDidChange()
    }

    private func resolveAssetID(
        wallpaperID: String,
        state: PersistedState,
        existingIDs: Set<String>
    ) -> String {
        if let existingRecord = state.managedAssets.first(where: { record in
            record.wallpaperID == wallpaperID
        }) {
            return existingRecord.assetID
        }

        return uniqueAssetID(
            from: "macwall-lock-\(wallpaperID)",
            existingIDs: existingIDs
        )
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
            throw LockScreenAerialServiceError.missingAerialManifest(Paths.entriesURL.path)
        }
    }

    private func thumbnailImage(for source: InstallSource) throws -> CGImage {
        let asset = AVURLAsset(url: source.videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = Constants.thumbnailSize
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let capturedImage: CGImage
        do {
            capturedImage = try generator.copyCGImage(
                at: CMTime(seconds: 1.0, preferredTimescale: 600),
                actualTime: nil
            )
        } catch {
            capturedImage = try generator.copyCGImage(
                at: CMTime(seconds: 0.1, preferredTimescale: 600),
                actualTime: nil
            )
        }

        return try normalizedThumbnailImage(from: capturedImage)
    }

    private func normalizedThumbnailImage(from image: CGImage) throws -> CGImage {
        let targetSize = Constants.thumbnailSize
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(targetSize.width),
                  height: Int(targetSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw LockScreenAerialServiceError.invalidImageEncoding
        }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: targetSize))
        context.interpolationQuality = .high

        let sourceSize = CGSize(width: image.width, height: image.height)
        let scale = max(
            targetSize.width / max(sourceSize.width, 1),
            targetSize.height / max(sourceSize.height, 1)
        )
        let scaledSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let drawRect = CGRect(
            x: (targetSize.width - scaledSize.width) / 2.0,
            y: (targetSize.height - scaledSize.height) / 2.0,
            width: scaledSize.width,
            height: scaledSize.height
        )

        context.draw(image, in: drawRect)

        guard let normalizedImage = context.makeImage() else {
            throw LockScreenAerialServiceError.invalidImageEncoding
        }

        return normalizedImage
    }

    private func writeThumbnailImage(_ cgImage: CGImage, to destinationURL: URL) throws {
        let imageRepresentation = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = imageRepresentation.representation(using: .png, properties: [:]) else {
            throw LockScreenAerialServiceError.invalidImageEncoding
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

    private func loadState() throws -> PersistedState {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return PersistedState()
        }

        let data = try Data(contentsOf: stateFileURL)
        return try JSONDecoder().decode(PersistedState.self, from: data)
    }

    private func normalizedState() throws -> PersistedState {
        var state = try loadState()
        let originalState = state
        let manifestAssetIDs: Set<String>

        if fileManager.fileExists(atPath: Paths.entriesURL.path) {
            let manifestData = try Data(contentsOf: Paths.entriesURL)
            manifestAssetIDs = try manifestEditor.assetIDs(in: manifestData)
        } else {
            manifestAssetIDs = []
        }

        state.managedAssets.removeAll { record in
            let videoExists = fileManager.fileExists(atPath: record.videoURL.path)
            let thumbnailExists = fileManager.fileExists(atPath: record.thumbnailURL.path)
            let manifestContainsAsset = manifestAssetIDs.isEmpty || manifestAssetIDs.contains(record.assetID)
            return !videoExists || !thumbnailExists || !manifestContainsAsset
        }

        state.originalSystemWallpaperURL = try sanitizedOriginalWallpaperURL(state.originalSystemWallpaperURL)

        if state != originalState {
            try saveState(state)
        }

        return state
    }

    private func saveState(_ state: PersistedState) throws {
        try fileManager.createDirectory(at: stateFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL, options: .atomic)
    }

    private func notifyStateDidChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func compareManagedAssets(_ lhs: ManagedAsset, _ rhs: ManagedAsset) -> Bool {
        switch (lhs.isActive, rhs.isActive) {
        case (true, false):
            return true
        case (false, true):
            return false
        default:
            break
        }

        switch (lhs.installedAt, rhs.installedAt) {
        case let (lhsDate?, rhsDate?):
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }

        if lhs.title != rhs.title {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return lhs.id < rhs.id
    }

    private func preferredReapplySource() throws -> InstallSource? {
        let store = WallpaperLibraryStore()
        if let sharedState = try store.loadSharedState() {
            let lockScreenPath = sharedState.lockScreen.videoPath ?? sharedState.videoPath
            let lockScreenTitle = sharedState.lockScreen.wallpaperTitle ?? sharedState.wallpaperTitle
            let wallpaperID = sharedState.lockScreen.wallpaperID ?? sharedState.selectedWallpaperID

            if let lockScreenPath,
               let lockScreenTitle,
               let wallpaperID {
                let videoURL = URL(fileURLWithPath: lockScreenPath)
                if fileManager.fileExists(atPath: videoURL.path) {
                    return InstallSource(
                        wallpaperID: wallpaperID,
                        title: lockScreenTitle,
                        videoURL: videoURL
                    )
                }
            }
        }

        let state = try normalizedState()
        let activeURLString = try readCurrentSystemWallpaperURL()
        let preferredRecord = state.managedAssets.first(where: { record in
            record.videoURL.absoluteString == activeURLString
        }) ?? state.managedAssets.sorted { lhs, rhs in
            lhs.installedAt > rhs.installedAt
        }.first

        guard let preferredRecord,
              fileManager.fileExists(atPath: preferredRecord.videoURL.path) else {
            return nil
        }

        return InstallSource(
            wallpaperID: preferredRecord.wallpaperID,
            title: preferredRecord.title,
            videoURL: preferredRecord.videoURL
        )
    }

    private func sanitizedOriginalWallpaperURL(_ urlString: String?) throws -> String? {
        guard let urlString, !urlString.isEmpty else {
            return nil
        }

        if try isMacWallAssetURLString(urlString) {
            return nil
        }

        guard let url = URL(string: urlString) else {
            return urlString
        }

        if url.isFileURL, !fileManager.fileExists(atPath: url.path) {
            return nil
        }

        return urlString
    }

    private func isMacWallAssetURLString(_ urlString: String) throws -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        if url.lastPathComponent.hasPrefix("macwall-lock-") {
            return true
        }

        return try macWallManifestAssets().contains { asset in
            asset.videoURL?.absoluteString == urlString
        }
    }

    private func macWallManifestAssets() throws -> [ManifestAsset] {
        try manifestAssets().filter(isMacWallAsset)
    }

    private func manifestAssets() throws -> [ManifestAsset] {
        guard fileManager.fileExists(atPath: Paths.entriesURL.path) else {
            return []
        }

        let data = try Data(contentsOf: Paths.entriesURL)
        guard let rootObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assetDictionaries = rootObject["assets"] as? [[String: Any]] else {
            return []
        }

        return assetDictionaries.compactMap { dictionary in
            guard let assetID = dictionary["id"] as? String else {
                return nil
            }

            let title = (dictionary["accessibilityLabel"] as? String)
                ?? (dictionary["localizedNameKey"] as? String)
                ?? assetID
            let videoURL = URL(string: dictionary["url-4K-SDR-240FPS"] as? String ?? "")
            let thumbnailURL = URL(string: dictionary["previewImage"] as? String ?? "")
            let shotID = dictionary["shotID"] as? String ?? ""

            return ManifestAsset(
                assetID: assetID,
                title: title,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                shotID: shotID
            )
        }
    }

    private func isMacWallAsset(_ asset: ManifestAsset) -> Bool {
        asset.shotID.hasPrefix("MACWALL_")
            || asset.assetID.hasPrefix("macwall-lock-")
            || asset.videoURL?.lastPathComponent.hasPrefix("macwall-lock-") == true
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

    private func removeItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func uniqueAssetID(from preferredText: String, existingIDs: Set<String>) -> String {
        let baseID = sanitizedAssetID(from: preferredText)
        guard existingIDs.contains(baseID) == false else {
            var counter = 2
            while existingIDs.contains("\(baseID)-\(counter)") {
                counter += 1
            }

            return "\(baseID)-\(counter)"
        }

        return baseID
    }

    private func sanitizedAssetID(from text: String) -> String {
        let loweredText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var result = ""
        var previousCharacterWasSeparator = false

        for character in loweredText {
            if character.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains) {
                result.append(character)
                previousCharacterWasSeparator = false
                continue
            }

            if character == "-" || character == "_" || character.unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains) {
                guard !result.isEmpty, !previousCharacterWasSeparator else {
                    continue
                }

                result.append("-")
                previousCharacterWasSeparator = true
            }
        }

        while let lastCharacter = result.last, lastCharacter == "-" || lastCharacter == "_" {
            result.removeLast()
        }

        return result.isEmpty ? "macwall-lock-screen" : result
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
            throw LockScreenAerialServiceError.commandFailed(message)
        }

        return output
    }
}
