import AVFoundation
import Foundation

struct VideoMetadata {
    let title: String
    let durationSeconds: Double
    let dimensions: CGSize
    let frameRate: Double
}

enum VideoFrameProviderError: LocalizedError {
    case noVideoTrack
    case notPrepared

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "The selected file does not contain a readable video track."
        case .notPrepared:
            return "No video is currently loaded."
        }
    }
}

@MainActor
final class VideoFrameProvider {
    private var currentURL: URL?
    private var imageGenerator: AVAssetImageGenerator?
    private var currentMetadata: VideoMetadata?

    func prepare(url: URL) async throws -> VideoMetadata {
        if currentURL == url, let currentMetadata {
            return currentMetadata
        }

        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoFrameProviderError.noVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let transformedSize = naturalSize.applying(preferredTransform)

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 3840, height: 2160)

        let metadata = VideoMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            durationSeconds: max(duration.seconds, 0.05),
            dimensions: CGSize(
                width: abs(transformedSize.width.rounded()),
                height: abs(transformedSize.height.rounded())
            ),
            frameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        )

        self.currentURL = url
        self.imageGenerator = imageGenerator
        self.currentMetadata = metadata

        return metadata
    }

    func copyFrame(for url: URL, at seconds: Double) async throws -> CGImage {
        let metadata = try await prepare(url: url)
        guard let imageGenerator else {
            throw VideoFrameProviderError.notPrepared
        }

        let clampedSeconds = min(
            max(seconds, 0),
            max(metadata.durationSeconds - 0.001, 0)
        )

        return try imageGenerator.copyCGImage(
            at: CMTime(seconds: clampedSeconds, preferredTimescale: 600),
            actualTime: nil
        )
    }
}
