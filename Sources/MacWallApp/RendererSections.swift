import AppKit
import SwiftUI

struct DesktopRendererSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var renderer: DesktopRendererService

    var body: some View {
        GroupBox("Desktop") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CompactStateLabel(
                        title: model.isDesktopRendererEnabled ? "Running" : "Off",
                        symbol: model.isDesktopRendererEnabled ? "play.rectangle.fill" : "pause.rectangle",
                        tint: model.isDesktopRendererEnabled ? .green : .secondary
                    )

                    Spacer()

                    CompactStateLabel(
                        title: "\(model.activeDisplays.count) display(s)",
                        symbol: "display.2",
                        tint: .secondary
                    )
                }

                Text(renderer.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ControlGroup {
                    Button("Refresh Displays") {
                        model.refreshDisplays()
                    }

                    Button(model.isDesktopRendererEnabled ? "Turn Off" : "Turn On") {
                        model.isDesktopRendererEnabled.toggle()
                    }

                    Button("Emergency Stop Wallpaper") {
                        model.emergencyStopRenderer()
                        renderer.disableNow()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LockScreenSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GroupBox("Lock Screen") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("MacWall renders your desktop while you’re logged in. This section controls the underlying Apple wallpaper path used by the lock screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let lockScreenEntry = model.lockScreenEntry {
                        CompactStateLabel(
                            title: lockScreenEntry.manifest.title,
                            symbol: "sparkles.tv",
                            tint: .secondary
                        )
                    }
                }

                Picker("Lock Screen Wallpaper", selection: $model.lockScreenMode) {
                    ForEach(LockScreenWallpaperMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                if model.lockScreenMode == .separateWallpaper, model.lockScreenWallpapers.isEmpty == false {
                    Picker(
                        "Wallpaper",
                        selection: Binding(
                            get: {
                                model.lockScreenWallpaperID ?? model.lockScreenWallpapers.first?.id ?? ""
                            },
                            set: { newValue in
                                model.lockScreenWallpaperID = newValue
                            }
                        )
                    ) {
                        ForEach(model.lockScreenWallpapers) { wallpaper in
                            Text(wallpaper.title).tag(wallpaper.id)
                        }
                    }
                    .labelsHidden()
                } else if model.lockScreenMode == .separateWallpaper {
                    Text("Import at least one local video wallpaper to choose a separate lock-screen wallpaper.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))

                    Text(model.lockScreenSummaryMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ControlGroup {
                        Button("Apply To Lock Screen") {
                            model.applyLockScreenWallpaper()
                        }
                        .disabled(!model.canApplyLockScreenWallpaper)

                        Button("Restore Original") {
                            model.restoreOriginalLockScreenWallpaper()
                        }
                        .disabled(!model.canRestoreOriginalLockScreenWallpaper)

                        Button("Settings") {
                            openSystemSettings()
                        }
                    }

                    DisclosureGroup("Current SystemWallpaperURL") {
                        CopyablePathRow(path: model.currentSystemWallpaperURL ?? "No explicit `SystemWallpaperURL` is currently set.")
                            .padding(.top, 4)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installed MacWall Assets")
                            .font(.subheadline.weight(.semibold))

                        if model.lockScreenInstalledAssets.isEmpty {
                            Text("No MacWall-managed lock-screen assets are installed in Apple’s aerial store.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.lockScreenInstalledAssets) { asset in
                                LockScreenAssetRow(asset: asset) {
                                    model.removeLockScreenAsset(asset.id)
                                }
                            }

                            Button("Remove All MacWall Assets", role: .destructive) {
                                model.removeAllLockScreenAssets()
                            }
                            .disabled(!model.hasInstalledLockScreenAssets)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openSystemSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

struct DiagnosticsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GroupBox("Diagnostics") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Power Log")
                    .font(.subheadline.weight(.semibold))
                CopyablePathRow(path: model.powerLogURL.path)

                Text("Shared State")
                    .font(.subheadline.weight(.semibold))
                CopyablePathRow(path: model.sharedStateURL.path)

                Text("Lock Screen State")
                    .font(.subheadline.weight(.semibold))
                CopyablePathRow(path: model.lockScreenAerialStateURL.path)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CopyablePathRow: View {
    let path: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(path)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                NSCursor.arrow.set()
            }
            .buttonStyle(.bordered)
        }
    }
}

struct DisplayAssignmentsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GroupBox("Displays") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Same wallpaper on every display", isOn: $model.isMirroringEnabled)

                ForEach(model.activeDisplays) { display in
                    HStack {
                        Text(display.name)
                        Spacer()

                        if model.isMirroringEnabled {
                            Text(model.selectedWallpaper?.title ?? "Unassigned")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(
                                display.name,
                                selection: Binding(
                                    get: {
                                        model.explicitAssignments[display.id] ?? model.selectedWallpaperID ?? ""
                                    },
                                    set: { newValue in
                                        model.setWallpaper(newValue, for: display.id)
                                    }
                                )
                            ) {
                                ForEach(model.wallpapers) { wallpaper in
                                    Text(wallpaper.title).tag(wallpaper.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220)
                        }
                    }
                }
                
                if model.isMirroringEnabled {
                    Text(model.selectedWallpaper?.title ?? "No wallpaper selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CompactStateLabel: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

private struct LockScreenAssetRow: View {
    let asset: LockScreenAerialService.ManagedAsset
    let removeAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(asset.title)
                        .font(.footnote.weight(.medium))

                    if asset.isActive {
                        CompactStateLabel(
                            title: "Active",
                            symbol: "checkmark.circle.fill",
                            tint: .green
                        )
                    }

                    if !asset.isTrackedByState {
                        CompactStateLabel(
                            title: "Manifest Only",
                            symbol: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                }

                Text(asset.id)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let videoURL = asset.videoURL {
                    Text(videoURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button("Remove", role: .destructive, action: removeAction)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
