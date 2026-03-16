import Foundation

extension RendererPlaybackMode {
    var storageLabel: String {
        switch self {
        case .playingFullQuality:
            return "playing_full_quality"
        case .playingReducedPower:
            return "playing_reduced_power"
        case .paused:
            return "paused"
        }
    }

    var badgeLabel: String {
        switch self {
        case .playingFullQuality:
            return "Full Quality"
        case .playingReducedPower:
            return "Reduced Power"
        case .paused:
            return "Paused"
        }
    }
}
