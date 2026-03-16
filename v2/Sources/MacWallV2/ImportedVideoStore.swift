@preconcurrency import AVFoundation
import Foundation

struct ImportedVideo {
    let originalURL: URL
    let localURL: URL
}

enum ImportedVideoStoreError: LocalizedError {
    case conversionNotSupported
    case exportFailed(String)
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .conversionNotSupported:
            return "MacWall v2 could not convert that video into a compatible .mov file."
        case let .exportFailed(message):
            return message.isEmpty
                ? "MacWall v2 failed while converting the video to .mov."
                : "MacWall v2 failed while converting the video to .mov: \(message)"
        case .exportCancelled:
            return "The video conversion was cancelled."
        }
    }
}

struct ImportedVideoStore {
    private let fileManager = FileManager.default

    func importVideo(from sourceURL: URL) async throws -> ImportedVideo {
        try AppPaths.ensureDirectoriesExist()

        let startedAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationDirectoryURL = AppPaths.importedVideosDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)

        let fileName = AerialAssetIdentity.sanitizedFileName(
            baseName: sourceURL.deletingPathExtension().lastPathComponent,
            fileExtension: "mov"
        )
        let destinationURL = destinationDirectoryURL.appendingPathComponent(fileName, isDirectory: false)

        try await copyOrConvertVideo(from: sourceURL, to: destinationURL)
        try pruneOldImports(keepingMostRecent: 5, excluding: destinationDirectoryURL)

        return ImportedVideo(
            originalURL: sourceURL,
            localURL: destinationURL
        )
    }

    private func pruneOldImports(keepingMostRecent count: Int, excluding currentDirectoryURL: URL) throws {
        let directoryContents = try fileManager.contentsOfDirectory(
            at: AppPaths.importedVideosDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let candidateDirectories = directoryContents.filter { entryURL in
            entryURL != currentDirectoryURL
        }

        let sortedDirectories = try candidateDirectories.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        for staleDirectoryURL in sortedDirectories.dropFirst(max(count - 1, 0)) {
            try? fileManager.removeItem(at: staleDirectoryURL)
        }
    }

    private func copyOrConvertVideo(from sourceURL: URL, to destinationURL: URL) async throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        if sourceURL.pathExtension.caseInsensitiveCompare("mov") == .orderedSame {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return
        }

        let asset = AVURLAsset(url: sourceURL)
        let exportSession = try makeExportSession(for: asset)
        exportSession.shouldOptimizeForNetworkUse = false
        do {
            try await exportSession.export(to: destinationURL, as: .mov)
        } catch is CancellationError {
            throw ImportedVideoStoreError.exportCancelled
        } catch {
            if let avError = error as? AVError, avError.code == .exportFailed {
                throw ImportedVideoStoreError.exportFailed(avError.localizedDescription)
            }

            throw ImportedVideoStoreError.exportFailed(error.localizedDescription)
        }
    }

    private func makeExportSession(for asset: AVAsset) throws -> AVAssetExportSession {
        for presetName in [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality] {
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
                continue
            }

            if exportSession.supportedFileTypes.contains(.mov) {
                return exportSession
            }
        }

        throw ImportedVideoStoreError.conversionNotSupported
    }
}
