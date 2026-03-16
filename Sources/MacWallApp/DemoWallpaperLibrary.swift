import MacWallCore

enum DemoWallpaperLibrary {
    static let entries: [WallpaperLibraryEntry] = [
        WallpaperLibraryEntry(
            manifest: WallpaperManifest(
                id: "aurora-swell",
                version: 1,
                title: "Aurora Swell",
                summary: "Soft gradient currents built for low-distraction desktop motion.",
                creator: WallpaperManifest.Creator(id: "studio.macwall", displayName: "MacWall Studio"),
                tags: ["gradient", "ambient", "calm"],
                category: "Featured",
                contentRating: .general,
                video: WallpaperManifest.VideoAsset(
                    fileName: "aurora-swell.mp4",
                    previewImageFileName: "aurora-swell.jpg",
                    container: .mp4,
                    codec: .hevc,
                    width: 3840,
                    height: 2160,
                    frameRate: 30,
                    durationSeconds: 45
                ),
                checksums: [
                    WallpaperManifest.Checksum(
                        fileName: "aurora-swell.mp4",
                        sha256: String(repeating: "a", count: 64)
                    ),
                    WallpaperManifest.Checksum(
                        fileName: "aurora-swell.jpg",
                        sha256: String(repeating: "b", count: 64)
                    ),
                ]
            ),
            videoURL: nil,
            previewImageURL: nil,
            source: .bundled
        ),
        WallpaperLibraryEntry(
            manifest: WallpaperManifest(
                id: "night-grid",
                version: 1,
                title: "Night Grid",
                summary: "Minimal motion lines designed for multi-display setups.",
                creator: WallpaperManifest.Creator(id: "grid-labs", displayName: "Grid Labs"),
                tags: ["neon", "grid", "minimal"],
                category: "Technology",
                contentRating: .general,
                video: WallpaperManifest.VideoAsset(
                    fileName: "night-grid.mov",
                    previewImageFileName: "night-grid.png",
                    container: .mov,
                    codec: .h264,
                    width: 2560,
                    height: 1440,
                    frameRate: 60,
                    durationSeconds: 20
                ),
                checksums: [
                    WallpaperManifest.Checksum(
                        fileName: "night-grid.mov",
                        sha256: String(repeating: "c", count: 64)
                    ),
                    WallpaperManifest.Checksum(
                        fileName: "night-grid.png",
                        sha256: String(repeating: "d", count: 64)
                    ),
                ]
            ),
            videoURL: nil,
            previewImageURL: nil,
            source: .bundled
        ),
        WallpaperLibraryEntry(
            manifest: WallpaperManifest(
                id: "forest-rain",
                version: 1,
                title: "Forest Rain",
                summary: "Muted rain motion with gentle pacing for focused work.",
                creator: WallpaperManifest.Creator(id: "northlight", displayName: "Northlight"),
                tags: ["nature", "rain", "focus"],
                category: "Nature",
                contentRating: .general,
                video: WallpaperManifest.VideoAsset(
                    fileName: "forest-rain.mp4",
                    previewImageFileName: "forest-rain.jpg",
                    container: .mp4,
                    codec: .hevc,
                    width: 1920,
                    height: 1080,
                    frameRate: 24,
                    durationSeconds: 30
                ),
                checksums: [
                    WallpaperManifest.Checksum(
                        fileName: "forest-rain.mp4",
                        sha256: String(repeating: "e", count: 64)
                    ),
                    WallpaperManifest.Checksum(
                        fileName: "forest-rain.jpg",
                        sha256: String(repeating: "f", count: 64)
                    ),
                ]
            ),
            videoURL: nil,
            previewImageURL: nil,
            source: .bundled
        ),
    ]
}
