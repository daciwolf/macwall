import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var isImportingVideo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                videoSection
                installSection
                librarySection
                systemSection
            }
            .padding(24)
        }
        .frame(minWidth: 920, minHeight: 720)
        .fileImporter(
            isPresented: $isImportingVideo,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .alert(
            "MacWall v2",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { presented in
                    if !presented {
                        model.dismissAlert()
                    }
                }
            ),
            actions: {
                Button("OK") {
                    model.dismissAlert()
                }
            },
            message: {
                Text(model.alertMessage ?? "")
            }
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MacWall v2")
                .font(.largeTitle.weight(.bold))

            Text("Import a compatible video, back up Apple’s current aerial state, add the new entry under the `Mac` wallpaper section, and optionally activate it by updating `SystemWallpaperURL`.")
                .foregroundStyle(.secondary)

            Label(model.statusMessage, systemImage: model.installedAssets.contains(where: \.isActive) ? "video.fill" : "shippingbox.fill")
                .font(.headline)

            Text(model.detailMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var videoSection: some View {
        GroupBox("Import Video") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button(model.importedVideoURL == nil ? "Import Video" : "Replace Video") {
                        isImportingVideo = true
                    }
                    .keyboardShortcut("i", modifiers: [.command])

                    if let path = model.importedVideoPath {
                        Text(path)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    } else {
                        Text("No imported video yet")
                            .foregroundStyle(.secondary)
                    }
                }

                if let metadata = model.videoMetadata {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(metadata.title, systemImage: "film")
                        Label("Working `.mov` files are preserved. Other formats are converted to `.mov` on import.", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        Label(
                            "\(Int(metadata.dimensions.width))x\(Int(metadata.dimensions.height))",
                            systemImage: "display"
                        )
                        Label(
                            String(format: "%.1f seconds at %.1f fps", metadata.durationSeconds, metadata.frameRate),
                            systemImage: "timer"
                        )
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("Import a local `.mov` or another video file, then add it to Apple’s `Mac` wallpaper library.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var installSection: some View {
        GroupBox("Add To Mac Wallpaper Library") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $model.installTitle)
                    .textFieldStyle(.roundedBorder)

                TextField("Asset ID", text: $model.installAssetID)
                    .textFieldStyle(.roundedBorder)

                Toggle("Activate immediately after adding", isOn: $model.activateAfterInstall)

                Text("Before modifying Apple’s wallpaper manifest, MacWall v2 creates timestamped backups of `entries.json` and `manifest.tar`. The video is copied into `aerials/videos`, a PNG thumbnail is written into `aerials/thumbnails`, and the new asset is appended under the `Mac` category.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Add To Mac Wallpaper Library") {
                    Task {
                        await model.installImportedVideo()
                    }
                }
                .disabled(model.importedVideoURL == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var librarySection: some View {
        GroupBox("Installed Assets") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(model.installedAssets.count) app-managed asset(s)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        model.refreshInstalledAssets()
                    }
                }

                if model.installedAssets.isEmpty {
                    Text("No app-managed custom Mac wallpapers are installed yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.installedAssets) { asset in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(asset.title)
                                    .font(.headline)

                                if asset.isActive {
                                    Text("Active")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.18), in: Capsule())
                                }

                                Spacer()

                                Button("Activate") {
                                    model.activateInstalledAsset(withID: asset.assetID)
                                }
                                .disabled(asset.isActive)

                                Button("Remove", role: .destructive) {
                                    model.removeInstalledAsset(withID: asset.assetID)
                                }
                            }

                            Text("Asset ID: \(asset.assetID)")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Text(asset.videoURL.path)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var systemSection: some View {
        GroupBox("System State") {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.currentSystemWallpaperURL ?? "No explicit `SystemWallpaperURL` is currently set.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack {
                    Button("Restore Original Wallpaper") {
                        model.restoreOriginalWallpaper()
                    }
                    .disabled(!model.canRestoreOriginalWallpaper)

                    Button("Refresh State") {
                        model.refreshInstalledAssets()
                    }
                }

                Text("Restoring the original wallpaper resets the private `SystemWallpaperURL` hook but does not delete the custom `Mac` wallpapers that were added through the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                return
            }

            Task {
                await model.importVideo(from: url)
            }
        case let .failure(error):
            model.alertMessage = error.localizedDescription
        }
    }
}
