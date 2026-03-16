import AppKit
import Foundation

struct ScreenSaverPhotoExporter {
    private let fileManager = FileManager.default
    private let store: WallpaperLibraryStore

    init(store: WallpaperLibraryStore) {
        self.store = store
    }

    @discardableResult
    func syncPhoto(for entry: WallpaperLibraryEntry?) throws -> URL? {
        let directoryURL = store.screenSaverPhotosDirectoryURL
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try clearDirectory(at: directoryURL)

        guard let entry else {
            return nil
        }

        if let previewImageURL = entry.previewImageURL,
           fileManager.fileExists(atPath: previewImageURL.macWallFileSystemPath) {
            let destinationURL = directoryURL.appendingPathComponent(
                "CurrentWallpaper.\(previewImageURL.pathExtension.isEmpty ? "jpg" : previewImageURL.pathExtension)",
                isDirectory: false
            )
            try fileManager.copyItem(at: previewImageURL, to: destinationURL)
            return destinationURL
        }

        let destinationURL = directoryURL.appendingPathComponent("CurrentWallpaper.jpg", isDirectory: false)
        try renderFallbackImage(for: entry, destinationURL: destinationURL)
        return destinationURL
    }

    private func clearDirectory(at directoryURL: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )

        for entryURL in contents {
            try? fileManager.removeItem(at: entryURL)
        }
    }

    private func renderFallbackImage(
        for entry: WallpaperLibraryEntry,
        destinationURL: URL
    ) throws {
        let size = NSSize(width: 1920, height: 1080)
        let image = NSImage(size: size)

        image.lockFocus()
        let bounds = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(
            colors: gradientColors(for: entry.id).map { color in
                NSColor(
                    hue: color.hue,
                    saturation: color.saturation,
                    brightness: color.brightness,
                    alpha: 1
                )
            }
        )
        gradient?.draw(in: bounds, angle: 315)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 74, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 30, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
        ]

        entry.manifest.title.draw(
            at: NSPoint(x: 96, y: 160),
            withAttributes: titleAttributes
        )
        entry.manifest.summary.draw(
            in: NSRect(x: 96, y: 72, width: 1300, height: 70),
            withAttributes: summaryAttributes
        )
        image.unlockFocus()

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let jpegData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.9]
            )
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try jpegData.write(to: destinationURL, options: .atomic)
    }

    private func gradientColors(for seed: String) -> [(hue: CGFloat, saturation: CGFloat, brightness: CGFloat)] {
        let scalarSum = seed.unicodeScalars.reduce(UInt32(0)) { partialResult, scalar in
            partialResult &+ scalar.value
        }

        return [
            (
                hue: CGFloat(scalarSum % 360) / 360,
                saturation: 0.62,
                brightness: 0.92
            ),
            (
                hue: CGFloat((scalarSum * 7) % 360) / 360,
                saturation: 0.48,
                brightness: 0.72
            ),
            (
                hue: CGFloat((scalarSum * 13) % 360) / 360,
                saturation: 0.38,
                brightness: 0.26
            ),
        ]
    }
}
