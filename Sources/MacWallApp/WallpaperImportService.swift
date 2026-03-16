import AppKit
import AVFoundation
import CoreMedia
import CryptoKit
import Foundation
import MacWallCore

enum WallpaperImportError: LocalizedError {
    case unsupportedContainer
    case unsupportedCodec
    case noVideoTrack
    case previewGenerationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedContainer:
            return "Only .mp4 and .mov video files are supported right now."
        case .unsupportedCodec:
            return "Only H.264 and HEVC video files are supported right now."
        case .noVideoTrack:
            return "The selected file does not contain a readable video track."
        case .previewGenerationFailed:
            return "MacWall could not generate a preview image for that video."
        }
    }
}

private struct ImportedWallpaperFiles {
    let directoryURL: URL
    let videoURL: URL
    let previewImageURL: URL
}

private struct ImportedVideoMetadata {
    let codec: WallpaperManifest.VideoAsset.Codec
    let width: Int
    let height: Int
    let frameRate: Double
    let durationSeconds: Double
}

struct WallpaperImportService: Sendable {
    private let store: WallpaperLibraryStore
    private let checksumChunkSize = 1_048_576

    init(store: WallpaperLibraryStore) {
        self.store = store
    }

    func importWallpaper(from sourceURL: URL) async throws -> WallpaperLibraryEntry {
        let startedAccessingSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccessingSecurityScopedResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let container = try resolveContainer(for: sourceURL)
        let files = try prepareFiles(for: container)
        var shouldRemoveImportedFiles = true
        defer {
            if shouldRemoveImportedFiles {
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: files.directoryURL)
            }
        }

        try copySourceVideo(from: sourceURL, to: files.videoURL)

        let asset = AVURLAsset(url: files.videoURL)
        let metadata = try await inspectVideoMetadata(for: asset)

        try generatePreviewImage(
            for: asset,
            durationSeconds: metadata.durationSeconds,
            destinationURL: files.previewImageURL
        )

        let manifest = try makeManifest(
            sourceURL: sourceURL,
            videoURL: files.videoURL,
            previewImageURL: files.previewImageURL,
            container: container,
            metadata: metadata
        )
        try writeManifest(manifest, to: files.directoryURL)

        shouldRemoveImportedFiles = false

        return WallpaperLibraryEntry(
            manifest: manifest,
            videoURL: files.videoURL,
            previewImageURL: files.previewImageURL,
            source: .imported
        )
    }

    private func prepareFiles(
        for container: WallpaperManifest.VideoAsset.Container
    ) throws -> ImportedWallpaperFiles {
        let directoryURL = try store.makeImportDirectory()
        return ImportedWallpaperFiles(
            directoryURL: directoryURL,
            videoURL: directoryURL.appendingPathComponent(
                "wallpaper.\(container.rawValue)",
                isDirectory: false
            ),
            previewImageURL: directoryURL.appendingPathComponent("preview.jpg", isDirectory: false)
        )
    }

    private func copySourceVideo(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path()) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func inspectVideoMetadata(for asset: AVURLAsset) async throws -> ImportedVideoMetadata {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw WallpaperImportError.noVideoTrack
        }

        let codec = try await resolveCodec(for: videoTrack)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let videoSize = naturalSize.applying(preferredTransform)

        return ImportedVideoMetadata(
            codec: codec,
            width: max(1, Int(abs(videoSize.width.rounded()))),
            height: max(1, Int(abs(videoSize.height.rounded()))),
            frameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 30,
            durationSeconds: max(duration.seconds, 1)
        )
    }

    private func makeManifest(
        sourceURL: URL,
        videoURL: URL,
        previewImageURL: URL,
        container: WallpaperManifest.VideoAsset.Container,
        metadata: ImportedVideoMetadata
    ) throws -> WallpaperManifest {
        let importedTitle = prettifiedTitle(from: sourceURL.deletingPathExtension().lastPathComponent)

        return WallpaperManifest(
            id: "imported-\(UUID().uuidString.lowercased())",
            version: 1,
            title: importedTitle,
            summary: "Imported from \(sourceURL.lastPathComponent).",
            creator: WallpaperManifest.Creator(id: "local-user", displayName: "Local Library"),
            tags: ["imported", "local"],
            category: "Imported",
            contentRating: .general,
            video: WallpaperManifest.VideoAsset(
                fileName: videoURL.lastPathComponent,
                previewImageFileName: previewImageURL.lastPathComponent,
                container: container,
                codec: metadata.codec,
                width: metadata.width,
                height: metadata.height,
                frameRate: metadata.frameRate,
                durationSeconds: metadata.durationSeconds
            ),
            checksums: try makeChecksums(
                for: [
                    videoURL,
                    previewImageURL,
                ]
            )
        )
    }

    private func makeChecksums(for fileURLs: [URL]) throws -> [WallpaperManifest.Checksum] {
        try fileURLs.map { fileURL in
            WallpaperManifest.Checksum(
                fileName: fileURL.lastPathComponent,
                sha256: try sha256(for: fileURL)
            )
        }
    }

    private func writeManifest(_ manifest: WallpaperManifest, to directoryURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestURL = directoryURL.appendingPathComponent("manifest.json", isDirectory: false)
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func resolveContainer(for sourceURL: URL) throws -> WallpaperManifest.VideoAsset.Container {
        switch sourceURL.pathExtension.lowercased() {
        case "mp4":
            return .mp4
        case "mov":
            return .mov
        default:
            throw WallpaperImportError.unsupportedContainer
        }
    }

    private func resolveCodec(for videoTrack: AVAssetTrack) async throws -> WallpaperManifest.VideoAsset.Codec {
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        guard let anyFormatDescription = formatDescriptions.first else {
            throw WallpaperImportError.unsupportedCodec
        }

        let formatDescriptionRef = anyFormatDescription as CFTypeRef
        guard CFGetTypeID(formatDescriptionRef) == CMFormatDescriptionGetTypeID() else {
            throw WallpaperImportError.unsupportedCodec
        }

        let formatDescription = unsafeDowncast(formatDescriptionRef, to: CMFormatDescription.self)
        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)

        switch codecType {
        case kCMVideoCodecType_H264:
            return .h264
        case kCMVideoCodecType_HEVC:
            return .hevc
        default:
            throw WallpaperImportError.unsupportedCodec
        }
    }

    private func generatePreviewImage(
        for asset: AVAsset,
        durationSeconds: Double,
        destinationURL: URL
    ) throws {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = NSSize(width: 1280, height: 720)

        let cgImage = try imageGenerator.copyCGImage(
            at: CMTime(seconds: min(1, max(durationSeconds / 10, 0)), preferredTimescale: 600),
            actualTime: nil
        )
        let bitmapRepresentation = NSBitmapImageRep(cgImage: cgImage)

        guard
            let jpegData = bitmapRepresentation.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.82]
            )
        else {
            throw WallpaperImportError.previewGenerationFailed
        }

        try jpegData.write(to: destinationURL, options: .atomic)
    }

    private func sha256(for fileURL: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()
        while true {
            let chunk = try fileHandle.read(upToCount: checksumChunkSize) ?? Data()
            if chunk.isEmpty {
                break
            }

            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func prettifiedTitle(from rawFileName: String) -> String {
        rawFileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
