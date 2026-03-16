import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var importedVideoURL: URL?
    @Published private(set) var videoMetadata: VideoMetadata?
    @Published var installTitle: String
    @Published var installAssetID: String
    @Published var activateAfterInstall: Bool
    @Published private(set) var installedAssets: [CustomAerialService.InstalledAsset]
    @Published private(set) var statusMessage: String
    @Published private(set) var detailMessage: String
    @Published private(set) var currentSystemWallpaperURL: String?
    @Published var alertMessage: String?

    private let videoInspector = VideoFrameProvider()
    private let customAerialService = CustomAerialService()

    init() {
        installTitle = ""
        installAssetID = ""
        activateAfterInstall = true
        installedAssets = []
        statusMessage = "Import a compatible video to add it to Apple’s Mac aerial wallpapers."
        detailMessage = "Before editing Apple’s manifest, MacWall v2 creates timestamped backups of `entries.json` and `manifest.tar`."
        currentSystemWallpaperURL = nil
        alertMessage = nil

        refreshInstalledAssets()
    }

    var importedVideoPath: String? {
        importedVideoURL?.path
    }

    var canRestoreOriginalWallpaper: Bool {
        customAerialService.canRestoreOriginalSystemWallpaper
    }

    func importVideo(from sourceURL: URL) async {
        do {
            let importedVideo = try await ImportedVideoStore().importVideo(from: sourceURL)
            let metadata = try await videoInspector.prepare(url: importedVideo.localURL)

            importedVideoURL = importedVideo.localURL
            videoMetadata = metadata
            installTitle = metadata.title
            installAssetID = AerialAssetIdentity.sanitizedAssetID(from: metadata.title)
            statusMessage = "Imported \(metadata.title)."
            detailMessage = "Ready to add \(metadata.title) to Apple’s `Mac` wallpaper section."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func installImportedVideo() async {
        guard let importedVideoURL else {
            alertMessage = "Import a video first."
            return
        }

        let resolvedTitle = resolvedInstallTitle()
        let preferredAssetID = installAssetID.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let thumbnailImage = try await videoInspector.copyFrame(
                for: importedVideoURL,
                at: suggestedThumbnailTimeSeconds()
            )
            let installation = try customAerialService.install(
                videoURL: importedVideoURL,
                title: resolvedTitle,
                preferredAssetID: preferredAssetID,
                thumbnailImage: thumbnailImage,
                activate: activateAfterInstall
            )

            refreshInstalledAssets()
            installTitle = installation.title
            installAssetID = installation.assetID
            statusMessage = activateAfterInstall
                ? "Added and activated \(installation.title)."
                : "Added \(installation.title) to the Mac wallpaper section."
            detailMessage = "Asset ID: \(installation.assetID). Manifest backup created before the write."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func activateInstalledAsset(withID assetID: String) {
        do {
            try customAerialService.activateAsset(withID: assetID)
            refreshInstalledAssets()

            if let asset = installedAssets.first(where: { installedAsset in
                installedAsset.assetID == assetID
            }) {
                statusMessage = "Activated \(asset.title)."
                detailMessage = "SystemWallpaperURL now points to \(asset.videoURL.lastPathComponent)."
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func removeInstalledAsset(withID assetID: String) {
        let removedTitle = installedAssets.first(where: { asset in
            asset.assetID == assetID
        })?.title ?? assetID

        do {
            try customAerialService.removeAsset(withID: assetID)
            refreshInstalledAssets()
            statusMessage = "Removed \(removedTitle)."
            detailMessage = "The asset was removed from Apple’s Mac wallpaper manifest entries, video cache, and thumbnail cache."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func restoreOriginalWallpaper() {
        do {
            try customAerialService.restoreOriginalSystemWallpaper()
            refreshInstalledAssets()
            statusMessage = "Restored the original system wallpaper."
            detailMessage = "App-managed custom Mac wallpapers remain installed in the library."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func refreshInstalledAssets() {
        do {
            installedAssets = try customAerialService.installedAssets()
            currentSystemWallpaperURL = try customAerialService.currentSystemWallpaperURL()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }

    private func resolvedInstallTitle() -> String {
        let trimmedTitle = installTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        if let videoMetadata {
            return videoMetadata.title
        }

        if let importedVideoURL {
            return importedVideoURL.deletingPathExtension().lastPathComponent
        }

        return "Custom Mac Wallpaper"
    }

    private func suggestedThumbnailTimeSeconds() -> Double {
        guard let videoMetadata else {
            return 0
        }

        let quarterPoint = videoMetadata.durationSeconds / 4
        return min(1.0, max(quarterPoint, 0))
    }
}
