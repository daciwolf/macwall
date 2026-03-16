public struct PlaybackContext: Equatable, Sendable {
    public enum PowerSource: String, CaseIterable, Sendable {
        case ac
        case battery
    }

    public enum ThermalState: String, CaseIterable, Comparable, Sendable {
        case nominal
        case fair
        case serious
        case critical

        public static func < (lhs: ThermalState, rhs: ThermalState) -> Bool {
            lhs.rank < rhs.rank
        }

        private var rank: Int {
            switch self {
            case .nominal:
                return 0
            case .fair:
                return 1
            case .serious:
                return 2
            case .critical:
                return 3
            }
        }
    }

    public enum UserPreference: String, CaseIterable, Sendable {
        case automatic
        case prioritizeQuality
        case prioritizeEfficiency
        case paused
    }

    public let powerSource: PowerSource
    public let thermalState: ThermalState
    public let isLowPowerModeEnabled: Bool
    public let hasFullscreenApp: Bool
    public let userPreference: UserPreference

    public init(
        powerSource: PowerSource,
        thermalState: ThermalState,
        isLowPowerModeEnabled: Bool,
        hasFullscreenApp: Bool,
        userPreference: UserPreference
    ) {
        self.powerSource = powerSource
        self.thermalState = thermalState
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.hasFullscreenApp = hasFullscreenApp
        self.userPreference = userPreference
    }
}

public struct PlaybackPolicy: Equatable, Sendable {
    public enum Action: String, Sendable {
        case play
        case pause
    }

    public enum Quality: String, Sendable {
        case full
        case reduced
    }

    public enum Reason: String, Sendable {
        case userRequestedPause
        case fullscreenAppActive
        case criticalThermalState
        case seriousThermalState
        case lowPowerModeEnabled
        case onBatteryPower
        case prioritizeEfficiency
        case prioritizeQuality
    }

    public let action: Action
    public let quality: Quality?
    public let reasons: [Reason]

    public init(action: Action, quality: Quality?, reasons: [Reason]) {
        self.action = action
        self.quality = quality
        self.reasons = reasons
    }
}

public struct PlaybackPolicyEngine: Sendable {
    public init() {}

    public func evaluate(context: PlaybackContext) -> PlaybackPolicy {
        if let pausedPolicy = pausePolicy(for: context) {
            return pausedPolicy
        }

        let qualityDecision = qualityDecision(for: context)

        return PlaybackPolicy(
            action: .play,
            quality: qualityDecision.quality,
            reasons: qualityDecision.reasons
        )
    }

    private func pausePolicy(for context: PlaybackContext) -> PlaybackPolicy? {
        if context.userPreference == .paused {
            return PlaybackPolicy(
                action: .pause,
                quality: nil,
                reasons: [.userRequestedPause]
            )
        }

        if context.hasFullscreenApp {
            return PlaybackPolicy(
                action: .pause,
                quality: nil,
                reasons: [.fullscreenAppActive]
            )
        }

        if context.thermalState == .critical {
            return PlaybackPolicy(
                action: .pause,
                quality: nil,
                reasons: [.criticalThermalState]
            )
        }

        return nil
    }

    private func qualityDecision(
        for context: PlaybackContext
    ) -> (quality: PlaybackPolicy.Quality, reasons: [PlaybackPolicy.Reason]) {
        var quality: PlaybackPolicy.Quality = .full
        var reasons: [PlaybackPolicy.Reason] = []

        if context.userPreference == .prioritizeEfficiency {
            quality = .reduced
            reasons.append(.prioritizeEfficiency)
        }

        if context.isLowPowerModeEnabled {
            quality = .reduced
            reasons.append(.lowPowerModeEnabled)
        }

        if context.thermalState == .serious {
            quality = .reduced
            reasons.append(.seriousThermalState)
        }

        if context.powerSource == .battery && context.userPreference != .prioritizeQuality {
            quality = .reduced
            reasons.append(.onBatteryPower)
        }

        if context.userPreference == .prioritizeQuality && quality == .full {
            reasons.append(.prioritizeQuality)
        }

        return (quality, reasons)
    }
}
