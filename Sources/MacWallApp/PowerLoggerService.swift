import Foundation
import IOKit.ps
import MacWallCore

struct PowerLogSnapshot {
    let selectedWallpaperID: String?
    let selectedWallpaperTitle: String?
    let rendererEnabled: Bool
    let rendererPlaybackMode: RendererPlaybackMode
    let activeDisplayCount: Int
    let policyPowerSource: PlaybackContext.PowerSource
    let policyThermalState: PlaybackContext.ThermalState
    let policyLowPowerModeEnabled: Bool
    let hasFullscreenApp: Bool
    let userPreference: PlaybackContext.UserPreference
    let playbackSpeed: Double
    let previewVolume: Double
    let isPreviewMuted: Bool
}

struct SystemPowerSample {
    let sourceState: String?
    let batteryPercent: Int?
    let isCharging: Bool?
    let voltageMillivolts: Int?
    let currentMilliamps: Int?
    let batteryWattsEstimate: Double?
    let adapterWatts: Int?
    let timeRemainingSeconds: Double?
}

enum PowerLogEvent: String {
    case startup
    case stateChange
    case periodic
}

@MainActor
final class PowerLoggerService {
    private static let csvHeader = [
        "timestamp",
        "event",
        "wallpaper_id",
        "wallpaper_title",
        "renderer_enabled",
        "renderer_playback_mode",
        "active_display_count",
        "policy_power_source",
        "policy_thermal_state",
        "policy_low_power_mode_enabled",
        "policy_has_fullscreen_app",
        "policy_user_preference",
        "playback_speed",
        "preview_volume",
        "preview_muted",
        "system_power_source_state",
        "battery_percent",
        "battery_is_charging",
        "battery_voltage_mv",
        "battery_current_ma",
        "battery_watts_estimate",
        "adapter_watts",
        "time_remaining_seconds",
    ].joined(separator: ",")

    private let store: WallpaperLibraryStore
    private let sampler = SystemPowerSampler()
    private let rowFormatter = PowerLogRowFormatter()
    private var timer: Timer?
    private var snapshotProvider: (() -> PowerLogSnapshot?)?

    init(store: WallpaperLibraryStore) {
        self.store = store
    }

    func start(snapshotProvider: @escaping () -> PowerLogSnapshot?) {
        self.snapshotProvider = snapshotProvider
        timer?.invalidate()

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.log(event: .periodic)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        log(event: .startup)
    }

    func recordStateChange() {
        log(event: .stateChange)
    }

    private func log(event: PowerLogEvent) {
        guard let snapshot = snapshotProvider?() else {
            return
        }

        let systemSample = sampler.sample()
        let row = rowFormatter.makeRow(
            snapshot: snapshot,
            systemSample: systemSample,
            event: event
        )

        do {
            try store.appendPowerLogRow(row, header: Self.csvHeader)
        } catch {
            FileHandle.standardError.write(Data("MacWall power logging failed: \(error)\n".utf8))
        }
    }
}

private struct SystemPowerSampler {
    func sample() -> SystemPowerSample {
        var sourceState: String?
        var batteryPercent: Int?
        var isCharging: Bool?
        var voltageMillivolts: Int?
        var currentMilliamps: Int?

        if
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        {
            for powerSource in list {
                guard
                    let description = IOPSGetPowerSourceDescription(snapshot, powerSource)?
                        .takeUnretainedValue() as? [String: Any],
                    (description[kIOPSIsPresentKey] as? Bool ?? true)
                else {
                    continue
                }

                sourceState = description[kIOPSPowerSourceStateKey] as? String
                isCharging = description[kIOPSIsChargingKey] as? Bool
                voltageMillivolts = description[kIOPSVoltageKey] as? Int
                currentMilliamps = description[kIOPSCurrentKey] as? Int

                if
                    let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                    let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
                    maxCapacity > 0
                {
                    batteryPercent = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
                }

                break
            }
        }

        let batteryWattsEstimate: Double?
        if let voltageMillivolts, let currentMilliamps {
            batteryWattsEstimate = abs(Double(voltageMillivolts) * Double(currentMilliamps)) / 1_000_000.0
        } else {
            batteryWattsEstimate = nil
        }

        let adapterWatts: Int?
        if let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            adapterWatts = adapterDetails[kIOPSPowerAdapterWattsKey] as? Int
        } else {
            adapterWatts = nil
        }

        let timeRemainingSeconds: Double?
        let timeRemainingEstimate = IOPSGetTimeRemainingEstimate()
        if timeRemainingEstimate < 0 {
            timeRemainingSeconds = nil
        } else {
            timeRemainingSeconds = timeRemainingEstimate
        }

        return SystemPowerSample(
            sourceState: sourceState,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            voltageMillivolts: voltageMillivolts,
            currentMilliamps: currentMilliamps,
            batteryWattsEstimate: batteryWattsEstimate,
            adapterWatts: adapterWatts,
            timeRemainingSeconds: timeRemainingSeconds
        )
    }
}
