import MacWallCore

extension PlaybackContext.PowerSource {
    var label: String {
        switch self {
        case .ac:
            return "AC Power"
        case .battery:
            return "Battery"
        }
    }
}

extension PlaybackContext.ThermalState {
    var label: String {
        switch self {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        }
    }
}

extension PlaybackContext.UserPreference {
    var label: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .prioritizeQuality:
            return "Quality"
        case .prioritizeEfficiency:
            return "Efficiency"
        case .paused:
            return "Paused"
        }
    }
}

extension PlaybackPolicy {
    var summary: String {
        switch action {
        case .pause:
            return "Playback paused"
        case .play:
            return "Playback \(quality == .reduced ? "reduced" : "full quality")"
        }
    }

    var symbolName: String {
        switch action {
        case .pause:
            return "pause.circle"
        case .play:
            return quality == .reduced ? "bolt.batteryblock" : "play.circle"
        }
    }
}

extension PlaybackPolicy.Reason {
    var label: String {
        switch self {
        case .userRequestedPause:
            return "Paused by user setting"
        case .fullscreenAppActive:
            return "Paused for fullscreen app"
        case .criticalThermalState:
            return "Paused for critical thermal pressure"
        case .seriousThermalState:
            return "Reduced for thermal pressure"
        case .lowPowerModeEnabled:
            return "Reduced for Low Power Mode"
        case .onBatteryPower:
            return "Reduced on battery"
        case .prioritizeEfficiency:
            return "Reduced by efficiency preference"
        case .prioritizeQuality:
            return "Maintaining full quality"
        }
    }
}

extension WallpaperPackageIssue {
    var label: String {
        switch self {
        case .invalidVersion:
            return "Manifest version must be greater than zero."
        case .titleEmpty:
            return "Title is required."
        case let .titleTooLong(length):
            return "Title is too long at \(length) characters."
        case let .summaryTooLong(length):
            return "Summary is too long at \(length) characters."
        case let .tooManyTags(count):
            return "Too many tags: \(count)."
        case .emptyTag:
            return "Tags cannot be blank."
        case .invalidDimensions:
            return "Video dimensions must be greater than zero."
        case .invalidFrameRate:
            return "Frame rate must be between 1 and 120 fps."
        case .invalidDuration:
            return "Duration must be between 0 and 14,400 seconds."
        case let .unsupportedPreviewImage(fileName):
            return "Preview image format is not supported: \(fileName)."
        case let .mismatchedVideoContainer(fileName):
            return "Video file extension does not match the declared container: \(fileName)."
        case let .missingRequiredFile(fileName):
            return "Required file missing: \(fileName)."
        case let .missingChecksum(fileName):
            return "Checksum missing for \(fileName)."
        case let .invalidChecksumFormat(fileName):
            return "Checksum is not a valid SHA-256 value for \(fileName)."
        case let .unexpectedFile(fileName):
            return "Unexpected file in package: \(fileName)."
        case let .tooManyFiles(count):
            return "Package contains too many files: \(count)."
        case let .packageTooLarge(size):
            return "Package exceeds the size limit at \(size) bytes."
        }
    }
}
