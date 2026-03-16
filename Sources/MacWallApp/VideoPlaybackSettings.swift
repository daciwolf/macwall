import AVFoundation
import Foundation

enum VideoScalingMode: String, CaseIterable, Equatable {
    case fill
    case fit

    var label: String {
        switch self {
        case .fill:
            return "Fill"
        case .fit:
            return "Fit"
        }
    }

    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill:
            return .resizeAspectFill
        case .fit:
            return .resizeAspect
        }
    }
}

struct VideoPlaybackSettings: Equatable {
    let isMuted: Bool
    let volume: Float
    let playbackRate: Float
    let scalingMode: VideoScalingMode

    var clampedPlaybackRate: Float {
        min(max(playbackRate, 0.25), 2.0)
    }

    var clampedVolume: Float {
        min(max(volume, 0), 1)
    }
}
