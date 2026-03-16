import Foundation

struct PowerLogRowFormatter {
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func makeRow(
        snapshot: PowerLogSnapshot,
        systemSample: SystemPowerSample,
        event: PowerLogEvent
    ) -> String {
        let timestamp = timestampFormatter.string(from: Date())

        return [
            csvField(timestamp),
            csvField(event.rawValue),
            csvField(snapshot.selectedWallpaperID),
            csvField(snapshot.selectedWallpaperTitle),
            csvField(snapshot.rendererEnabled),
            csvField(snapshot.rendererPlaybackMode.storageLabel),
            csvField(snapshot.activeDisplayCount),
            csvField(snapshot.policyPowerSource.rawValue),
            csvField(snapshot.policyThermalState.rawValue),
            csvField(snapshot.policyLowPowerModeEnabled),
            csvField(snapshot.hasFullscreenApp),
            csvField(snapshot.userPreference.rawValue),
            csvField(snapshot.playbackSpeed),
            csvField(snapshot.previewVolume),
            csvField(snapshot.isPreviewMuted),
            csvField(systemSample.sourceState),
            csvField(systemSample.batteryPercent),
            csvField(systemSample.isCharging),
            csvField(systemSample.voltageMillivolts),
            csvField(systemSample.currentMilliamps),
            csvField(systemSample.batteryWattsEstimate),
            csvField(systemSample.adapterWatts),
            csvField(systemSample.timeRemainingSeconds),
        ].joined(separator: ",")
    }

    private func csvField<T: CustomStringConvertible>(_ value: T?) -> String {
        guard let value else {
            return ""
        }

        return csvField(value.description)
    }

    private func csvField(_ value: String?) -> String {
        guard let value else {
            return ""
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
