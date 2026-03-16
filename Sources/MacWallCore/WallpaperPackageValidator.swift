public struct WallpaperPackageConstraints: Equatable, Sendable {
    public let maximumFileCount: Int
    public let maximumPackageSizeInBytes: Int
    public let maximumTagCount: Int
    public let maximumTitleLength: Int
    public let maximumSummaryLength: Int

    public init(
        maximumFileCount: Int = 8,
        maximumPackageSizeInBytes: Int = 500 * 1_024 * 1_024,
        maximumTagCount: Int = 10,
        maximumTitleLength: Int = 80,
        maximumSummaryLength: Int = 280
    ) {
        self.maximumFileCount = maximumFileCount
        self.maximumPackageSizeInBytes = maximumPackageSizeInBytes
        self.maximumTagCount = maximumTagCount
        self.maximumTitleLength = maximumTitleLength
        self.maximumSummaryLength = maximumSummaryLength
    }

    public static let `default` = Self()
}

public enum WallpaperPackageIssue: Equatable, Sendable {
    case invalidVersion
    case titleEmpty
    case titleTooLong(Int)
    case summaryTooLong(Int)
    case tooManyTags(Int)
    case emptyTag
    case invalidDimensions
    case invalidFrameRate
    case invalidDuration
    case unsupportedPreviewImage(String)
    case mismatchedVideoContainer(String)
    case missingRequiredFile(String)
    case missingChecksum(String)
    case invalidChecksumFormat(String)
    case unexpectedFile(String)
    case tooManyFiles(Int)
    case packageTooLarge(Int)
}

public struct WallpaperPackageValidator: Sendable {
    public let constraints: WallpaperPackageConstraints

    public init(constraints: WallpaperPackageConstraints = .default) {
        self.constraints = constraints
    }

    public func validate(
        manifest: WallpaperManifest,
        availableFiles: Set<String>,
        totalPackageSizeInBytes: Int? = nil
    ) -> [WallpaperPackageIssue] {
        var issues: [WallpaperPackageIssue] = []

        if manifest.version <= 0 {
            issues.append(.invalidVersion)
        }

        let trimmedTitle = trim(manifest.title)
        if trimmedTitle.isEmpty {
            issues.append(.titleEmpty)
        }

        if manifest.title.count > constraints.maximumTitleLength {
            issues.append(.titleTooLong(manifest.title.count))
        }

        if manifest.summary.count > constraints.maximumSummaryLength {
            issues.append(.summaryTooLong(manifest.summary.count))
        }

        if manifest.tags.count > constraints.maximumTagCount {
            issues.append(.tooManyTags(manifest.tags.count))
        }

        if manifest.tags.contains(where: { trim($0).isEmpty }) {
            issues.append(.emptyTag)
        }

        if manifest.video.width <= 0 || manifest.video.height <= 0 {
            issues.append(.invalidDimensions)
        }

        if manifest.video.frameRate <= 0 || manifest.video.frameRate > 120 {
            issues.append(.invalidFrameRate)
        }

        if manifest.video.durationSeconds <= 0 || manifest.video.durationSeconds > 14_400 {
            issues.append(.invalidDuration)
        }

        let previewExtension = fileExtension(for: manifest.video.previewImageFileName)
        if !["jpg", "jpeg", "png"].contains(previewExtension) {
            issues.append(.unsupportedPreviewImage(manifest.video.previewImageFileName))
        }

        if fileExtension(for: manifest.video.fileName) != manifest.video.container.rawValue {
            issues.append(.mismatchedVideoContainer(manifest.video.fileName))
        }

        for requiredFile in manifest.requiredPackageFiles.sorted() where !availableFiles.contains(requiredFile) {
            issues.append(.missingRequiredFile(requiredFile))
        }

        let checksumFileNames = Set(manifest.checksums.map(\.fileName))
        for requiredFile in [manifest.video.fileName, manifest.video.previewImageFileName].sorted()
        where !checksumFileNames.contains(requiredFile) {
            issues.append(.missingChecksum(requiredFile))
        }

        for checksum in manifest.checksums {
            if !isValidSHA256(checksum.sha256) {
                issues.append(.invalidChecksumFormat(checksum.fileName))
            }
        }

        for fileName in availableFiles.subtracting(manifest.requiredPackageFiles).sorted() {
            issues.append(.unexpectedFile(fileName))
        }

        if availableFiles.count > constraints.maximumFileCount {
            issues.append(.tooManyFiles(availableFiles.count))
        }

        if let totalPackageSizeInBytes, totalPackageSizeInBytes > constraints.maximumPackageSizeInBytes {
            issues.append(.packageTooLarge(totalPackageSizeInBytes))
        }

        return issues
    }

    private func fileExtension(for fileName: String) -> String {
        guard let fragment = fileName.split(separator: ".").last, fileName.contains(".") else {
            return ""
        }

        return fragment.lowercased()
    }

    private func isValidSHA256(_ candidate: String) -> Bool {
        candidate.count == 64 && candidate.allSatisfy(\.isHexDigit)
    }

    private func trim(_ value: String) -> String {
        let trimmedLeading = value.drop(while: \.isWhitespace)
        let trimmedTrailing = trimmedLeading.reversed().drop(while: \.isWhitespace).reversed()
        return String(trimmedTrailing)
    }
}
