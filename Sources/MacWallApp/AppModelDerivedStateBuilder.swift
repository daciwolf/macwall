import Foundation
import MacWallCore

struct AppModelDerivedStateBuilder {
    private let playbackEngine = PlaybackPolicyEngine()
    private let assignmentPlanner = DisplayAssignmentPlanner()
    private let validator = WallpaperPackageValidator()

    func selectedEntry(
        in libraryEntries: [WallpaperLibraryEntry],
        selectedWallpaperID: String?
    ) -> WallpaperLibraryEntry? {
        guard let selectedWallpaperID else {
            return libraryEntries.first
        }

        return libraryEntries.first(where: { $0.id == selectedWallpaperID }) ?? libraryEntries.first
    }

    func playbackPolicy(
        powerSource: PlaybackContext.PowerSource,
        thermalState: PlaybackContext.ThermalState,
        isLowPowerModeEnabled: Bool,
        hasFullscreenApp: Bool,
        userPreference: PlaybackContext.UserPreference
    ) -> PlaybackPolicy {
        playbackEngine.evaluate(
            context: PlaybackContext(
                powerSource: powerSource,
                thermalState: thermalState,
                isLowPowerModeEnabled: isLowPowerModeEnabled,
                hasFullscreenApp: hasFullscreenApp,
                userPreference: userPreference
            )
        )
    }

    func displayAssignments(
        selectedWallpaper: WallpaperManifest?,
        isMirroringEnabled: Bool,
        explicitAssignments: [String: String],
        activeDisplays: [DisplayOption]
    ) -> [DisplayAssignment] {
        guard let selectedWallpaper else {
            return []
        }

        let strategy: WallpaperAssignmentStrategy
        if isMirroringEnabled {
            strategy = .mirrored(wallpaperID: selectedWallpaper.id)
        } else {
            strategy = .explicit(
                assignments: explicitAssignments,
                fallbackWallpaperID: selectedWallpaper.id
            )
        }

        return assignmentPlanner.plan(activeDisplays: activeDisplays.map(\.id), strategy: strategy)
    }

    func rendererSnapshot(
        isEnabled: Bool,
        assignments: [DisplayAssignment],
        libraryEntries: [WallpaperLibraryEntry],
        playbackPolicy: PlaybackPolicy,
        playbackSpeed: Double,
        scalingMode: VideoScalingMode
    ) -> DesktopRendererSnapshot {
        DesktopRendererSnapshot(
            isEnabled: isEnabled,
            assignments: assignments,
            libraryEntries: libraryEntries,
            playbackMode: rendererPlaybackMode(for: playbackPolicy),
            videoSettings: rendererVideoSettings(
                playbackSpeed: playbackSpeed,
                scalingMode: scalingMode
            )
        )
    }

    func packageIssues(for entry: WallpaperLibraryEntry?) -> [WallpaperPackageIssue] {
        guard let entry else {
            return []
        }

        return validator.validate(
            manifest: entry.manifest,
            availableFiles: entry.availableFilesForValidation,
            totalPackageSizeInBytes: 75 * 1_024 * 1_024
        )
    }

    func previewVideoSettings(
        isMuted: Bool,
        volume: Double,
        playbackSpeed: Double,
        scalingMode: VideoScalingMode
    ) -> VideoPlaybackSettings {
        VideoPlaybackSettings(
            isMuted: isMuted,
            volume: Float(volume),
            playbackRate: Float(playbackSpeed),
            scalingMode: scalingMode
        )
    }

    func lockScreenEntry(
        libraryEntries: [WallpaperLibraryEntry],
        selectedEntry: WallpaperLibraryEntry?,
        lockScreenMode: LockScreenWallpaperMode,
        lockScreenWallpaperID: String?
    ) -> WallpaperLibraryEntry? {
        switch lockScreenMode {
        case .inheritDesktop:
            return selectedEntry
        case .separateWallpaper:
            guard let lockScreenWallpaperID else {
                return selectedEntry
            }

            return libraryEntries.first(where: { $0.id == lockScreenWallpaperID }) ?? selectedEntry
        }
    }

    func powerLogSnapshot(
        selectedEntry: WallpaperLibraryEntry?,
        rendererEnabled: Bool,
        activeDisplays: [DisplayOption],
        powerSource: PlaybackContext.PowerSource,
        thermalState: PlaybackContext.ThermalState,
        isLowPowerModeEnabled: Bool,
        hasFullscreenApp: Bool,
        userPreference: PlaybackContext.UserPreference,
        playbackSpeed: Double,
        previewVolume: Double,
        isPreviewMuted: Bool,
        playbackPolicy: PlaybackPolicy
    ) -> PowerLogSnapshot {
        PowerLogSnapshot(
            selectedWallpaperID: selectedEntry?.id,
            selectedWallpaperTitle: selectedEntry?.manifest.title,
            rendererEnabled: rendererEnabled,
            rendererPlaybackMode: rendererPlaybackMode(for: playbackPolicy),
            activeDisplayCount: activeDisplays.count,
            policyPowerSource: powerSource,
            policyThermalState: thermalState,
            policyLowPowerModeEnabled: isLowPowerModeEnabled,
            hasFullscreenApp: hasFullscreenApp,
            userPreference: userPreference,
            playbackSpeed: playbackSpeed,
            previewVolume: previewVolume,
            isPreviewMuted: isPreviewMuted
        )
    }

    func sharedState(
        selectedEntry: WallpaperLibraryEntry?,
        rendererEnabled: Bool,
        displayAssignments: [DisplayAssignment],
        playbackPolicy: PlaybackPolicy,
        lockScreenMode: LockScreenWallpaperMode,
        lockScreenEntry: WallpaperLibraryEntry?
    ) -> MacWallSharedState {
        MacWallSharedState(
            updatedAt: Date(),
            selectedWallpaperID: selectedEntry?.id,
            wallpaperTitle: selectedEntry?.manifest.title,
            wallpaperSummary: selectedEntry?.manifest.summary,
            videoPath: selectedEntry?.videoURL?.macWallFileSystemPath,
            previewImagePath: selectedEntry?.previewImageURL?.macWallFileSystemPath,
            rendererEnabled: rendererEnabled,
            playbackMode: rendererPlaybackMode(for: playbackPolicy).storageLabel,
            assignments: displayAssignments.map { assignment in
                MacWallSharedState.Assignment(
                    displayID: assignment.displayID,
                    wallpaperID: assignment.wallpaperID
                )
            },
            lockScreen: MacWallSharedState.LockScreen(
                mode: lockScreenMode,
                wallpaperID: lockScreenEntry?.id,
                wallpaperTitle: lockScreenEntry?.manifest.title,
                wallpaperSummary: lockScreenEntry?.manifest.summary,
                videoPath: lockScreenEntry?.videoURL?.macWallFileSystemPath,
                previewImagePath: lockScreenEntry?.previewImageURL?.macWallFileSystemPath
            )
        )
    }

    private func rendererPlaybackMode(for playbackPolicy: PlaybackPolicy) -> RendererPlaybackMode {
        switch playbackPolicy.action {
        case .pause:
            return .paused
        case .play:
            return playbackPolicy.quality == .reduced
                ? .playingReducedPower
                : .playingFullQuality
        }
    }

    private func rendererVideoSettings(
        playbackSpeed: Double,
        scalingMode: VideoScalingMode
    ) -> VideoPlaybackSettings {
        VideoPlaybackSettings(
            isMuted: true,
            volume: 0,
            playbackRate: Float(playbackSpeed),
            scalingMode: scalingMode
        )
    }
}
