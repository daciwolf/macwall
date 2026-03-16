public struct WallpaperManifest: Codable, Equatable, Identifiable, Sendable {
    public struct Creator: Codable, Equatable, Sendable {
        public let id: String
        public let displayName: String

        public init(id: String, displayName: String) {
            self.id = id
            self.displayName = displayName
        }
    }

    public struct VideoAsset: Codable, Equatable, Sendable {
        public enum Container: String, Codable, CaseIterable, Sendable {
            case mp4
            case mov
        }

        public enum Codec: String, Codable, CaseIterable, Sendable {
            case h264
            case hevc
        }

        public let fileName: String
        public let previewImageFileName: String
        public let container: Container
        public let codec: Codec
        public let width: Int
        public let height: Int
        public let frameRate: Double
        public let durationSeconds: Double

        public init(
            fileName: String,
            previewImageFileName: String,
            container: Container,
            codec: Codec,
            width: Int,
            height: Int,
            frameRate: Double,
            durationSeconds: Double
        ) {
            self.fileName = fileName
            self.previewImageFileName = previewImageFileName
            self.container = container
            self.codec = codec
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.durationSeconds = durationSeconds
        }
    }

    public struct Checksum: Codable, Equatable, Sendable {
        public let fileName: String
        public let sha256: String

        public init(fileName: String, sha256: String) {
            self.fileName = fileName
            self.sha256 = sha256
        }
    }

    public enum ContentRating: String, Codable, CaseIterable, Sendable {
        case general
        case mature
    }

    public let id: String
    public let version: Int
    public let title: String
    public let summary: String
    public let creator: Creator
    public let tags: [String]
    public let category: String
    public let contentRating: ContentRating
    public let video: VideoAsset
    public let checksums: [Checksum]

    public init(
        id: String,
        version: Int,
        title: String,
        summary: String,
        creator: Creator,
        tags: [String],
        category: String,
        contentRating: ContentRating,
        video: VideoAsset,
        checksums: [Checksum]
    ) {
        self.id = id
        self.version = version
        self.title = title
        self.summary = summary
        self.creator = creator
        self.tags = tags
        self.category = category
        self.contentRating = contentRating
        self.video = video
        self.checksums = checksums
    }

    public var requiredPackageFiles: Set<String> {
        [
            "manifest.json",
            video.fileName,
            video.previewImageFileName,
        ]
    }
}
