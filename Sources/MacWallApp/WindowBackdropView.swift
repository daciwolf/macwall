import AppKit
import SwiftUI

struct WindowConfiguratorView: NSViewRepresentable {
    let windowID: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView)
    }

    private func configureWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.level = .normal
            window.collectionBehavior.subtract([
                .canJoinAllSpaces,
                .stationary,
                .ignoresCycle,
                .fullScreenAuxiliary,
            ])
            window.ignoresMouseEvents = false
            window.hidesOnDeactivate = false
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.isMovableByWindowBackground = false
            window.toolbarStyle = .unifiedCompact
            window.identifier = NSUserInterfaceItemIdentifier(windowID)
        }
    }
}
