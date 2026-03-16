import Foundation
import MacWallCore
import SwiftUI

struct PlaybackControlsSection: View {
    @ObservedObject var model: AppModel

    private let playbackSpeedOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        GroupBox("Playback") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Mute", isOn: $model.isPreviewMuted)
                    Spacer()
                    Picker("Speed", selection: $model.playbackSpeed) {
                        ForEach(playbackSpeedOptions, id: \.self) { rate in
                            Text(speedLabel(for: rate)).tag(rate)
                        }
                    }
                    .frame(width: 90)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(model.previewVolume * 100))%")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $model.previewVolume, in: 0...1)
                        .disabled(model.isPreviewMuted)
                }

                Picker("Scale", selection: $model.videoScalingMode) {
                    ForEach(VideoScalingMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func speedLabel(for rate: Double) -> String {
        if rate == floor(rate) {
            return "\(Int(rate))x"
        }

        return String(format: "%.2gx", rate)
    }
}

struct PlaybackPolicySection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GroupBox("Power") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Power", selection: $model.powerSource) {
                        ForEach(PlaybackContext.PowerSource.allCases, id: \.self) { source in
                            Text(source.label).tag(source)
                        }
                    }

                    Picker("Thermal", selection: $model.thermalState) {
                        ForEach(PlaybackContext.ThermalState.allCases, id: \.self) { state in
                            Text(state.label).tag(state)
                        }
                    }

                    Picker("Preference", selection: $model.userPreference) {
                        ForEach(PlaybackContext.UserPreference.allCases, id: \.self) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                }

                Toggle("Low Power Mode", isOn: $model.isLowPowerModeEnabled)
                Toggle("Fullscreen App Active", isOn: $model.hasFullscreenApp)

                Label(model.playbackPolicy.summary, systemImage: model.playbackPolicy.symbolName)
                    .font(.subheadline.weight(.semibold))

                if !model.playbackPolicy.reasons.isEmpty {
                    Text(model.playbackPolicy.reasons.map(\.label).joined(separator: " • "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
