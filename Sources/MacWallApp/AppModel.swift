import Combine
import Foundation
import MacWallCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var libraryEntries: [WallpaperLibraryEntry] {
        didSet {
            handleStateMutation()
        }
    }
    @Published var selectedWallpaperID: String? {
        didSet {
            handleStateMutation()
        }
    }
    @Published var powerSource: PlaybackContext.PowerSource {
        didSet {
            handleStateMutation()
        }
    }
    @Published var thermalState: PlaybackContext.ThermalState {
        didSet {
            handleStateMutation()
        }
    }
    @Published var isLowPowerModeEnabled: Bool {
        didSet {
            handleStateMutation()
        }
    }
    @Published var hasFullscreenApp: Bool {
        didSet {
            handleStateMutation()
        }
    }
    @Published var userPreference: PlaybackContext.UserPreference {
        didSet {
            handleStateMutation()
        }
    }
    @Published var isMirroringEnabled: Bool {
        didSet {
            handleStateMutation()
        }
    }
    @Published var isDesktopRendererEnabled: Bool {
        didSet {
            handleStateMutation()
        }
    }
    @Published var activeDisplays: [DisplayOption] {
        didSet {
            handleStateMutation()
        }
    }
    @Published var explicitAssignments: [String: String] {
        didSet {
            handleStateMutation()
        }
    }
    @Published var previewVolume: Double {
        didSet {
            handleStateMutation()
        }
    }
    @Published var isPreviewMuted: Bool {
        didSet {
            handleStateMutation()
        }
    }
    @Published var playbackSpeed: Double {
        didSet {
            handleStateMutation()
        }
    }
    @Published var videoScalingMode: VideoScalingMode {
        didSet {
            handleStateMutation()
        }
    }
    @Published var lockScreenMode: LockScreenWallpaperMode {
        didSet {
            persistLockScreenPreferences()
            handleStateMutation()
        }
    }
    @Published var lockScreenWallpaperID: String? {
        didSet {
            persistLockScreenPreferences()
            handleStateMutation()
        }
    }
    @Published private(set) var lockScreenInstalledAssets: [LockScreenAerialService.ManagedAsset]
    @Published private(set) var currentSystemWallpaperURL: String?
    @Published var alertMessage: String?

    private let explicitAssignmentNormalizer = ExplicitDisplayAssignmentNormalizer()
    private let derivedStateBuilder = AppModelDerivedStateBuilder()
    private let libraryStore: WallpaperLibraryStore
    private let libraryRepository: WallpaperLibraryRepository
    private let lockScreenPreferencesStore: LockScreenPreferencesStore
    private let lockScreenAerialService: LockScreenAerialService
    private let powerLogger: PowerLoggerService
    private var cancellables: Set<AnyCancellable>

    init() {
        let libraryStore = WallpaperLibraryStore()
        self.libraryStore = libraryStore
        libraryRepository = WallpaperLibraryRepository(store: libraryStore)
        lockScreenPreferencesStore = LockScreenPreferencesStore()
        lockScreenAerialService = .shared
        powerLogger = PowerLoggerService(store: libraryStore)

        let initialLibraryEntries = libraryRepository.loadLibraryEntries()
        let lockScreenPreferences = lockScreenPreferencesStore.load()

        libraryEntries = initialLibraryEntries
        selectedWallpaperID = initialLibraryEntries.first?.id
        powerSource = .ac
        thermalState = .nominal
        isLowPowerModeEnabled = false
        hasFullscreenApp = false
        userPreference = .automatic
        isMirroringEnabled = true
        isDesktopRendererEnabled = true
        activeDisplays = []
        explicitAssignments = [:]
        previewVolume = 0.7
        isPreviewMuted = false
        playbackSpeed = 1.0
        videoScalingMode = .fill
        lockScreenMode = lockScreenPreferences.mode
        lockScreenWallpaperID = lockScreenPreferences.wallpaperID
        lockScreenInstalledAssets = []
        currentSystemWallpaperURL = nil
        alertMessage = nil
        cancellables = []

        refreshDisplays()
        reconcileLockScreenSelection()
        persistSharedState()
        refreshLockScreenState()
        observeLockScreenStateChanges()
        powerLogger.start { [weak self] in
            self?.powerLogSnapshot
        }
    }

    var wallpapers: [WallpaperManifest] {
        libraryEntries.map(\.manifest)
    }

    var selectedEntry: WallpaperLibraryEntry? {
        derivedStateBuilder.selectedEntry(
            in: libraryEntries,
            selectedWallpaperID: selectedWallpaperID
        )
    }

    var selectedWallpaper: WallpaperManifest? {
        selectedEntry?.manifest
    }

    var playbackPolicy: PlaybackPolicy {
        derivedStateBuilder.playbackPolicy(
            powerSource: powerSource,
            thermalState: thermalState,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            hasFullscreenApp: hasFullscreenApp,
            userPreference: userPreference
        )
    }

    var displayAssignments: [DisplayAssignment] {
        derivedStateBuilder.displayAssignments(
            selectedWallpaper: selectedWallpaper,
            isMirroringEnabled: isMirroringEnabled,
            explicitAssignments: explicitAssignments,
            activeDisplays: activeDisplays
        )
    }

    var rendererSnapshot: DesktopRendererSnapshot {
        derivedStateBuilder.rendererSnapshot(
            isEnabled: isDesktopRendererEnabled,
            assignments: displayAssignments,
            libraryEntries: libraryEntries,
            playbackPolicy: playbackPolicy,
            playbackSpeed: playbackSpeed,
            scalingMode: videoScalingMode
        )
    }

    var packageIssues: [WallpaperPackageIssue] {
        derivedStateBuilder.packageIssues(for: selectedEntry)
    }

    var sharedStateURL: URL {
        libraryStore.sharedStateURL
    }

    var powerLogURL: URL {
        libraryStore.powerLogURL
    }

    var lockScreenAerialStateURL: URL {
        libraryStore.lockScreenAerialStateURL
    }

    var previewVideoSettings: VideoPlaybackSettings {
        derivedStateBuilder.previewVideoSettings(
            isMuted: isPreviewMuted,
            volume: previewVolume,
            playbackSpeed: playbackSpeed,
            scalingMode: videoScalingMode
        )
    }

    var lockScreenEntry: WallpaperLibraryEntry? {
        derivedStateBuilder.lockScreenEntry(
            libraryEntries: libraryEntries,
            selectedEntry: selectedEntry,
            lockScreenMode: lockScreenMode,
            lockScreenWallpaperID: lockScreenWallpaperID
        )
    }

    var lockScreenWallpapers: [WallpaperManifest] {
        libraryEntries
            .filter { $0.videoURL != nil }
            .map(\.manifest)
    }

    var lockScreenInstallableEntry: WallpaperLibraryEntry? {
        guard let lockScreenEntry, lockScreenEntry.videoURL != nil else {
            return nil
        }

        return lockScreenEntry
    }

    var canApplyLockScreenWallpaper: Bool {
        lockScreenInstallableEntry != nil
    }

    var canRestoreOriginalLockScreenWallpaper: Bool {
        lockScreenAerialService.canRestoreOriginalSystemWallpaper
    }

    var hasInstalledLockScreenAssets: Bool {
        lockScreenInstalledAssets.isEmpty == false
    }

    var lockScreenSummaryMessage: String {
        if let lockScreenInstallableEntry {
            return "Ready to apply `\(lockScreenInstallableEntry.manifest.title)` to the underlying system wallpaper used by the lock screen."
        }

        if let lockScreenEntry {
            return "`\(lockScreenEntry.manifest.title)` does not have a local video file. Import a real video wallpaper before applying it to the lock screen."
        }

        return "Select an imported wallpaper with a local video file to use the lock-screen install path."
    }

    func wallpaperTitle(for wallpaperID: String) -> String {
        libraryEntries.first(where: { $0.id == wallpaperID })?.manifest.title ?? wallpaperID
    }

    func displayName(for displayID: String) -> String {
        activeDisplays.first(where: { $0.id == displayID })?.name ?? displayID
    }

    func setWallpaper(_ wallpaperID: String, for displayID: String) {
        explicitAssignments[displayID] = wallpaperID
    }

    func emergencyStopRenderer() {
        isDesktopRendererEnabled = false
    }

    func applyLockScreenWallpaper() {
        guard let lockScreenInstallableEntry else {
            alertMessage = lockScreenSummaryMessage
            return
        }

        do {
            let installation = try lockScreenAerialService.installWallpaper(for: lockScreenInstallableEntry)
            refreshLockScreenState()
            alertMessage = "Applied \(installation.title) to the underlying system wallpaper. MacWall’s desktop renderer remains the logged-in presentation layer."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func restoreOriginalLockScreenWallpaper() {
        do {
            try lockScreenAerialService.restoreOriginalSystemWallpaper()
            refreshLockScreenState()
            alertMessage = "Restored the original system wallpaper for the lock-screen path."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func removeLockScreenAsset(_ assetID: String) {
        removeLockScreenAssets(withIDs: [assetID])
    }

    func removeAllLockScreenAssets() {
        removeLockScreenAssets(withIDs: lockScreenInstalledAssets.map(\.id))
    }

    func refreshLockScreenState() {
        do {
            currentSystemWallpaperURL = try lockScreenAerialService.currentSystemWallpaperURL()
            lockScreenInstalledAssets = try lockScreenAerialService.installedAssets()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func refreshDisplays() {
        let discoveredDisplays = DisplayCatalog.currentOptions()
        activeDisplays = discoveredDisplays.isEmpty
            ? [DisplayOption(id: "fallback-primary", name: "Primary Display")]
            : discoveredDisplays

        explicitAssignments = explicitAssignmentNormalizer.normalize(
            activeDisplays: activeDisplays.map(\.id),
            currentAssignments: explicitAssignments,
            availableWallpaperIDs: libraryEntries.map(\.id)
        )
        reconcileLockScreenSelection()
    }

    func importWallpaper(from sourceURL: URL) async {
        do {
            let importService = WallpaperImportService(store: libraryStore)
            let importedEntry = try await importService.importWallpaper(from: sourceURL)
            libraryEntries.insert(importedEntry, at: 0)
            selectedWallpaperID = importedEntry.id

            if isMirroringEnabled {
                for display in activeDisplays {
                    explicitAssignments[display.id] = importedEntry.id
                }
            }

            try libraryRepository.saveImportedEntries(from: libraryEntries)
            reconcileLockScreenSelection()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }

    private func removeLockScreenAssets(withIDs assetIDs: [String]) {
        do {
            let removedCount = try lockScreenAerialService.removeAssets(withIDs: assetIDs)
            refreshLockScreenState()
            if removedCount > 0 {
                alertMessage = removedCount == 1
                    ? "Removed 1 lock-screen asset from Apple’s wallpaper store."
                    : "Removed \(removedCount) lock-screen assets from Apple’s wallpaper store."
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private var powerLogSnapshot: PowerLogSnapshot {
        derivedStateBuilder.powerLogSnapshot(
            selectedEntry: selectedEntry,
            rendererEnabled: isDesktopRendererEnabled,
            activeDisplays: activeDisplays,
            powerSource: powerSource,
            thermalState: thermalState,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            hasFullscreenApp: hasFullscreenApp,
            userPreference: userPreference,
            playbackSpeed: playbackSpeed,
            previewVolume: previewVolume,
            isPreviewMuted: isPreviewMuted,
            playbackPolicy: playbackPolicy
        )
    }

    private func handleStateMutation() {
        persistSharedState()
        powerLogger.recordStateChange()
    }

    private func persistSharedState() {
        let sharedState = derivedStateBuilder.sharedState(
            selectedEntry: selectedEntry,
            rendererEnabled: isDesktopRendererEnabled,
            displayAssignments: displayAssignments,
            playbackPolicy: playbackPolicy,
            lockScreenMode: lockScreenMode,
            lockScreenEntry: lockScreenEntry
        )

        do {
            try libraryStore.saveSharedState(sharedState)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func persistLockScreenPreferences() {
        lockScreenPreferencesStore.save(
            LockScreenPreferences(
                mode: lockScreenMode,
                wallpaperID: lockScreenWallpaperID
            )
        )
    }

    private func reconcileLockScreenSelection() {
        guard lockScreenMode == .separateWallpaper else {
            return
        }

        let availableWallpaperIDs = Set(
            libraryEntries.compactMap { entry in
                entry.videoURL != nil ? entry.id : nil
            }
        )
        if let lockScreenWallpaperID, availableWallpaperIDs.contains(lockScreenWallpaperID) {
            return
        }

        if let selectedWallpaperID,
           availableWallpaperIDs.contains(selectedWallpaperID) {
            lockScreenWallpaperID = selectedWallpaperID
            return
        }

        lockScreenWallpaperID = libraryEntries.first(where: { $0.videoURL != nil })?.id
    }

    private func observeLockScreenStateChanges() {
        NotificationCenter.default.publisher(for: LockScreenAerialService.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshLockScreenState()
                }
            }
            .store(in: &cancellables)
    }
}
