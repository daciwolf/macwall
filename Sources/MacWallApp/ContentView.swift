import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var renderer: DesktopRendererService
    @State private var isImportingVideo = false
    @State private var presentedAdvancedPanel: AdvancedPanel?

    var body: some View {
        NavigationSplitView {
            WallpaperLibrarySidebarView(model: model)
        } detail: {
            WallpaperDetailView(model: model, renderer: renderer)
        }
        .background(WindowConfiguratorView(windowID: MacWallWindowID.main))
        .safeAreaInset(edge: .bottom) {
            RendererStatusBar(model: model, renderer: renderer)
        }
        .toolbar {
            ToolbarItem {
                Button("Import Video") {
                    isImportingVideo = true
                }
            }

            ToolbarItem {
                Menu {
                    Button("Power & Playback") {
                        presentedAdvancedPanel = .powerAndPlayback
                    }

                    Button("Diagnostics") {
                        presentedAdvancedPanel = .diagnostics
                    }
                } label: {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingVideo,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .sheet(item: $presentedAdvancedPanel) { panel in
            AdvancedPanelSheet(panel: panel, model: model)
        }
        .alert(
            "MacWall",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { shouldPresent in
                    if !shouldPresent {
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
        .task {
            model.refreshDisplays()
            syncRenderer()
        }
        .onChange(of: model.rendererSnapshot, initial: true) { _, _ in
            syncRenderer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSCursor.arrow.set()
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                return
            }

            Task {
                await model.importWallpaper(from: url)
            }
        case let .failure(error):
            model.alertMessage = error.localizedDescription
        }
    }

    private func syncRenderer() {
        renderer.apply(snapshot: model.rendererSnapshot)
    }
}

private struct RendererStatusBar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var renderer: DesktopRendererService

    var body: some View {
        HStack {
            Text(renderer.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Emergency Stop Wallpaper") {
                model.emergencyStopRenderer()
                renderer.disableNow()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
