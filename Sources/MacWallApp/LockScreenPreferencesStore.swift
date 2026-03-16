import Foundation

struct LockScreenPreferences: Equatable {
    let mode: LockScreenWallpaperMode
    let wallpaperID: String?
}

struct LockScreenPreferencesStore {
    private let userDefaults: UserDefaults
    private let modeKey = "MacWall.lockScreen.mode"
    private let wallpaperIDKey = "MacWall.lockScreen.wallpaperID"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> LockScreenPreferences {
        let mode = LockScreenWallpaperMode(
            rawValue: userDefaults.string(forKey: modeKey) ?? ""
        ) ?? .inheritDesktop

        return LockScreenPreferences(
            mode: mode,
            wallpaperID: userDefaults.string(forKey: wallpaperIDKey)
        )
    }

    func save(_ preferences: LockScreenPreferences) {
        userDefaults.set(preferences.mode.rawValue, forKey: modeKey)
        userDefaults.set(preferences.wallpaperID, forKey: wallpaperIDKey)
    }
}
