import AppKit
import MacWallCore
import SwiftUI

enum RendererPlaybackMode: Equatable {
    case playingFullQuality
    case playingReducedPower
    case paused
}

struct DesktopRendererSnapshot: Equatable {
    let isEnabled: Bool
    let assignments: [DisplayAssignment]
    let libraryEntries: [WallpaperLibraryEntry]
    let playbackMode: RendererPlaybackMode
    let videoSettings: VideoPlaybackSettings
}

@MainActor
final class DesktopRendererService: ObservableObject {
    static let shared = DesktopRendererService()

    @Published private(set) var statusMessage = "Renderer disabled"

    private var windowsByDisplayID: [String: NSWindow] = [:]
    private var lastAppliedSnapshot: DesktopRendererSnapshot?
    private var reorderWorkItem: DispatchWorkItem?

    func apply(snapshot: DesktopRendererSnapshot) {
        lastAppliedSnapshot = snapshot
        guard snapshot.isEnabled else {
            disableNow()
            return
        }

        let displaysByID = Dictionary(
            uniqueKeysWithValues: DisplayCatalog.currentEntries().map { ($0.id, $0) }
        )
        let entriesByID = Dictionary(
            uniqueKeysWithValues: snapshot.libraryEntries.map { ($0.id, $0) }
        )
        let assignedDisplayIDs = Set(snapshot.assignments.map(\.displayID))

        for displayID in windowsByDisplayID.keys where !assignedDisplayIDs.contains(displayID) {
            windowsByDisplayID[displayID]?.orderOut(nil)
            windowsByDisplayID.removeValue(forKey: displayID)
        }

        var renderedCount = 0

        for assignment in snapshot.assignments {
            guard let display = displaysByID[assignment.displayID] else {
                continue
            }

            let window = windowsByDisplayID[assignment.displayID] ?? makeWindow(for: display.screen)
            configure(
                window: window,
                wallpaperEntry: entriesByID[assignment.wallpaperID],
                playbackMode: snapshot.playbackMode,
                videoSettings: snapshot.videoSettings
            )
            window.setFrame(display.screen.frame, display: true)
            window.orderFrontRegardless()
            windowsByDisplayID[assignment.displayID] = window
            renderedCount += 1
        }

        if renderedCount == 0 {
            statusMessage = "Renderer enabled, but no matching displays were found"
        } else {
            switch snapshot.playbackMode {
            case .playingFullQuality:
                statusMessage = "Rendering desktop wallpaper on \(renderedCount) display(s)"
            case .playingReducedPower:
                statusMessage = "Rendering in reduced-power mode on \(renderedCount) display(s)"
            case .paused:
                statusMessage = "Renderer windows are visible, but playback is paused"
            }
        }
    }

    func disableNow() {
        reorderWorkItem?.cancel()
        tearDownAllWindows()
        statusMessage = "Renderer disabled"
    }

    func rebuildDesktopWindows(using snapshot: DesktopRendererSnapshot) {
        tearDownAllWindows()
        apply(snapshot: snapshot)
    }

    func reorderWindows() {
        reorderWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performReorderWindows()
        }

        reorderWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func tearDownAllWindows() {
        for window in windowsByDisplayID.values {
            window.orderOut(nil)
            window.close()
        }

        windowsByDisplayID.removeAll()
    }

    private func performReorderWindows() {
        guard let snapshot = lastAppliedSnapshot, snapshot.isEnabled else {
            return
        }

        let displaysByID = Dictionary(
            uniqueKeysWithValues: DisplayCatalog.currentEntries().map { ($0.id, $0) }
        )
        let entriesByID = Dictionary(
            uniqueKeysWithValues: snapshot.libraryEntries.map { ($0.id, $0) }
        )
        let assignedDisplayIDs = Set(snapshot.assignments.compactMap { assignment in
            displaysByID[assignment.displayID] != nil ? assignment.displayID : nil
        })

        for displayID in windowsByDisplayID.keys where !assignedDisplayIDs.contains(displayID) {
            windowsByDisplayID[displayID]?.orderOut(nil)
            windowsByDisplayID[displayID]?.close()
            windowsByDisplayID.removeValue(forKey: displayID)
        }

        var renderedCount = 0

        for assignment in snapshot.assignments {
            guard let display = displaysByID[assignment.displayID] else {
                continue
            }

            let window: NSWindow
            if let existingWindow = windowsByDisplayID[assignment.displayID] {
                window = existingWindow
            } else {
                window = makeWindow(for: display.screen)
                configure(
                    window: window,
                    wallpaperEntry: entriesByID[assignment.wallpaperID],
                    playbackMode: snapshot.playbackMode,
                    videoSettings: snapshot.videoSettings
                )
                windowsByDisplayID[assignment.displayID] = window
            }

            window.orderOut(nil)
            window.setFrame(display.screen.frame, display: true)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.orderBack(nil)
            renderedCount += 1
        }

        updateStatusMessage(renderedCount: renderedCount, playbackMode: snapshot.playbackMode)
    }

    private func updateStatusMessage(
        renderedCount: Int,
        playbackMode: RendererPlaybackMode
    ) {
        if renderedCount == 0 {
            statusMessage = "Renderer enabled, but no matching displays were found"
        } else {
            switch playbackMode {
            case .playingFullQuality:
                statusMessage = "Rendering desktop wallpaper on \(renderedCount) display(s)"
            case .playingReducedPower:
                statusMessage = "Rendering in reduced-power mode on \(renderedCount) display(s)"
            case .paused:
                statusMessage = "Renderer windows are visible, but playback is paused"
            }
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        window.backgroundColor = .black
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isMovable = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        return window
    }

    private func configure(
        window: NSWindow,
        wallpaperEntry: WallpaperLibraryEntry?,
        playbackMode: RendererPlaybackMode,
        videoSettings: VideoPlaybackSettings
    ) {
        window.contentView = NSHostingView(
            rootView: DesktopWallpaperStage(
                wallpaperEntry: wallpaperEntry,
                playbackMode: playbackMode,
                videoSettings: videoSettings
            )
        )
    }
}

private struct DesktopWallpaperStage: View {
    let wallpaperEntry: WallpaperLibraryEntry?
    let playbackMode: RendererPlaybackMode
    let videoSettings: VideoPlaybackSettings

    var body: some View {
        let palette = colorPalette(for: wallpaperEntry?.id ?? "macwall")

        ZStack {
            if let videoURL = wallpaperEntry?.videoURL {
                LoopingVideoView(
                    url: videoURL,
                    settings: videoSettings,
                    playbackMode: playbackMode
                )
            } else {
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func colorPalette(for seed: String) -> [Color] {
        let buckets = Array(seed.unicodeScalars).map(\.value).reduce(into: [UInt32]()) { partialResult, value in
            partialResult.append(value)
        }
        let sum = buckets.reduce(0, +)
        let hueA = Double(sum % 360) / 360.0
        let hueB = Double((sum * 7) % 360) / 360.0
        let hueC = Double((sum * 13) % 360) / 360.0

        return [
            Color(hue: hueA, saturation: 0.62, brightness: 0.95),
            Color(hue: hueB, saturation: 0.52, brightness: 0.72),
            Color(hue: hueC, saturation: 0.40, brightness: 0.28),
        ]
    }
}
