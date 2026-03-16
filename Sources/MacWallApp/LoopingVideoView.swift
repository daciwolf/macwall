import AppKit
import AVFoundation
import SwiftUI

struct LoopingVideoView: NSViewRepresentable {
    let url: URL
    let settings: VideoPlaybackSettings
    let playbackMode: RendererPlaybackMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        context.coordinator.attach(to: view)
        context.coordinator.configure(
            url: url,
            settings: settings,
            playbackMode: playbackMode
        )
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        context.coordinator.attach(to: nsView)
        context.coordinator.configure(
            url: url,
            settings: settings,
            playbackMode: playbackMode
        )
    }

    @MainActor
    final class Coordinator {
        private let player = AVQueuePlayer()
        private let playerLayer = AVPlayerLayer()

        private var looper: AVPlayerLooper?
        private var currentSourceKey: SourceKey?
        private weak var containerView: PlayerContainerView?

        init() {
            player.preventsDisplaySleepDuringVideoPlayback = false
            player.automaticallyWaitsToMinimizeStalling = false
            player.actionAtItemEnd = .none
            playerLayer.player = player
            playerLayer.backgroundColor = NSColor.black.cgColor
        }

        func attach(to view: PlayerContainerView) {
            guard containerView !== view else {
                return
            }

            containerView = view
            view.install(playerLayer: playerLayer)
        }

        func configure(
            url: URL,
            settings: VideoPlaybackSettings,
            playbackMode: RendererPlaybackMode
        ) {
            let sourceKey = SourceKey(url: url, playbackMode: playbackMode)
            if currentSourceKey != sourceKey {
                currentSourceKey = sourceKey
                replacePlaybackItem(url: url, playbackMode: playbackMode)
            }

            player.isMuted = settings.isMuted
            player.volume = settings.clampedVolume
            playerLayer.videoGravity = settings.scalingMode.videoGravity

            switch playbackMode {
            case .paused:
                player.pause()
            case .playingFullQuality, .playingReducedPower:
                DispatchQueue.main.async { [player] in
                    player.playImmediately(atRate: settings.clampedPlaybackRate)
                }
            }
        }

        private func replacePlaybackItem(url: URL, playbackMode: RendererPlaybackMode) {
            player.pause()
            player.removeAllItems()

            let item = AVPlayerItem(url: url)
            item.audioTimePitchAlgorithm = .spectral
            item.preferredForwardBufferDuration = playbackMode == .playingReducedPower ? 0.15 : 0.5
            item.preferredPeakBitRate = playbackMode == .playingReducedPower ? 2_000_000 : 0
            item.preferredMaximumResolution = playbackMode == .playingReducedPower
                ? CGSize(width: 1280, height: 720)
                : .zero

            looper = AVPlayerLooper(player: player, templateItem: item)
        }
    }
}

final class PlayerContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.sublayers?.forEach { $0.frame = bounds }
    }

    func install(playerLayer: AVPlayerLayer) {
        wantsLayer = true

        if layer == nil {
            layer = CALayer()
            layer?.backgroundColor = NSColor.black.cgColor
        }

        if playerLayer.superlayer !== layer {
            layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            layer?.addSublayer(playerLayer)
        }

        needsLayout = true
    }
}

private struct SourceKey: Equatable {
    let url: URL
    let playbackMode: RendererPlaybackMode
}
