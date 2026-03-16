import Foundation
import MacWallCore

enum DemoWallpaperLibrary {
    static let entries: [WallpaperLibraryEntry] = [
        makeEntry(
            id: "vtf5-uci-rocket-project",
            title: "VTF5 UCI Rocket Project",
            summary: "Default flight footage courtesy of UCI Rocket Project.",
            tags: ["rocket", "vtf5", "uci", "flight"],
            videoFileName: "VTF5UCIRocketProject.mov",
            previewFileName: "VTF5UCIRocketProject.jpg",
            codec: .h264,
            width: 3840,
            height: 2160,
            frameRate: 23.976,
            durationSeconds: 36.536,
            videoSHA256: "6897bff2ad02c7d1823cf36aa88c6b578540a31010d6fa4265e6b8b986bd1da2",
            previewSHA256: "52b2bbddb61b088a44198aaa9236deaa6d4cb2940a708a4ac8f75b8dfe836204"
        ),
        makeEntry(
            id: "vtf5-uci-rocket-project-color-grade",
            title: "VTF5 UCI Rocket Project Color Grade",
            summary: "Color graded default flight footage courtesy of UCI Rocket Project.",
            tags: ["rocket", "vtf5", "uci", "flight", "color-grade"],
            videoFileName: "VTF5UCIRocketProjectColorGrade.mov",
            previewFileName: "VTF5UCIRocketProjectColorGrade.jpg",
            codec: .hevc,
            width: 3840,
            height: 2160,
            frameRate: 23.976,
            durationSeconds: 36.495,
            videoSHA256: "f8d174d3903e9d131f1bbed53b8b36b0adff618a5a79b003c3fd3c2eacc3be91",
            previewSHA256: "4cd26ae5d83d8b4594dadc979d972116976753222e2f87014302bb249be4852e"
        ),
    ]

    private static func makeEntry(
        id: String,
        title: String,
        summary: String,
        tags: [String],
        videoFileName: String,
        previewFileName: String,
        codec: WallpaperManifest.VideoAsset.Codec,
        width: Int,
        height: Int,
        frameRate: Double,
        durationSeconds: Double,
        videoSHA256: String,
        previewSHA256: String
    ) -> WallpaperLibraryEntry {
        WallpaperLibraryEntry(
            manifest: WallpaperManifest(
                id: id,
                version: 1,
                title: title,
                summary: summary,
                creator: WallpaperManifest.Creator(
                    id: "uci-rocket-project",
                    displayName: "UCI Rocket Project"
                ),
                tags: tags,
                category: "Aerospace",
                contentRating: .general,
                video: WallpaperManifest.VideoAsset(
                    fileName: videoFileName,
                    previewImageFileName: previewFileName,
                    container: .mov,
                    codec: codec,
                    width: width,
                    height: height,
                    frameRate: frameRate,
                    durationSeconds: durationSeconds
                ),
                checksums: [
                    WallpaperManifest.Checksum(
                        fileName: videoFileName,
                        sha256: videoSHA256
                    ),
                    WallpaperManifest.Checksum(
                        fileName: previewFileName,
                        sha256: previewSHA256
                    ),
                ]
            ),
            videoURL: bundledWallpaperURL(fileName: videoFileName),
            previewImageURL: bundledWallpaperURL(fileName: previewFileName),
            source: .bundled
        )
    }

    private static func bundledWallpaperURL(fileName: String) -> URL? {
        let fileManager = FileManager.default

        if let packagedResourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("BundledWallpapers", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false),
           fileManager.fileExists(atPath: packagedResourceURL.path) {
            return packagedResourceURL
        }

        let sourceResourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BundledWallpapers", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)

        guard fileManager.fileExists(atPath: sourceResourceURL.path) else {
            return nil
        }

        return sourceResourceURL
    }
}
