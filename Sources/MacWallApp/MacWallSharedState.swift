import Foundation

enum LockScreenWallpaperMode: String, Codable, CaseIterable {
    case inheritDesktop
    case separateWallpaper

    var label: String {
        switch self {
        case .inheritDesktop:
            return "Same as Desktop"
        case .separateWallpaper:
            return "Different Wallpaper"
        }
    }
}

struct MacWallSharedState: Codable, Equatable {
    struct Assignment: Codable, Equatable {
        let displayID: String
        let wallpaperID: String
    }

    struct LockScreen: Codable, Equatable {
        let mode: LockScreenWallpaperMode
        let wallpaperID: String?
        let wallpaperTitle: String?
        let wallpaperSummary: String?
        let videoPath: String?
        let previewImagePath: String?
    }

    let updatedAt: Date
    let selectedWallpaperID: String?
    let wallpaperTitle: String?
    let wallpaperSummary: String?
    let videoPath: String?
    let previewImagePath: String?
    let rendererEnabled: Bool
    let playbackMode: String
    let assignments: [Assignment]
    let lockScreen: LockScreen
}
