import AppKit
import SwiftUI

enum MacWallWindowID {
    static let main = "main-window"
}

@main
struct MacWallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var renderer = DesktopRendererService.shared

    var body: some Scene {
        Window("MacWall", id: MacWallWindowID.main) {
            ContentView(model: model, renderer: renderer)
                .frame(minWidth: 960, minHeight: 640)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    renderer.disableNow()
                }
        }

        MenuBarExtra("MacWall", systemImage: "photo.stack") {
            MenuBarExtraContent(model: model, renderer: renderer)
        }
    }
}

private struct MenuBarExtraContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var renderer: DesktopRendererService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Desktop Wallpaper Window", isOn: $model.isDesktopRendererEnabled)
        Button("Show Main Window") {
            openWindow(id: MacWallWindowID.main)
            NSApp.activate(ignoringOtherApps: true)

            DispatchQueue.main.async {
                NSApp.windows
                    .filter { $0.identifier?.rawValue == MacWallWindowID.main || $0.title == "MacWall" }
                    .forEach { window in
                        window.deminiaturize(nil)
                        window.makeKeyAndOrderFront(nil)
                    }
            }
        }
        Button("Emergency Stop Wallpaper") {
            model.emergencyStopRenderer()
            renderer.disableNow()
        }
        Divider()
        Text(renderer.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        Divider()
        Button("Quit MacWall") {
            renderer.disableNow()
            NSApp.terminate(nil)
        }
    }
}
