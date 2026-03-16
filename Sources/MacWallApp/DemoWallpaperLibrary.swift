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
            codec: .hevc,
            width: 1920,
            height: 1080,
            frameRate: 23.976024627685547,
            durationSeconds: 36.5365,
            videoSHA256: "131411b4c1605d59b5458c445a2725efe5d07dbccd33c07520cdb3e9c332ffa0",
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
            width: 1920,
            height: 1080,
            frameRate: 23.976024627685547,
            durationSeconds: 36.52133333333333,
            videoSHA256: "25a2934c161c94945d69c5529223c053234aaaab56c0cff9ac988177e0613628",
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
