@main
struct CoreTestMain {
    static func main() throws {
        let tests: [(String, () throws -> Void)] = [
            ("valid manifest produces no issues", testValidManifestProducesNoIssues),
            ("validator flags missing files and unexpected entries", testValidatorFlagsMissingFilesAndUnexpectedEntries),
            ("validator rejects unexpected files even with checksums", testValidatorRejectsUnexpectedChecksummedFiles),
            ("validator flags metadata and checksum problems", testValidatorFlagsMetadataAndChecksumProblems),
            ("fullscreen app pauses playback", testFullscreenAppPausesPlayback),
            ("battery and low power reduce playback", testBatteryAndLowPowerReducePlayback),
            ("quality preference keeps full quality", testQualityPreferenceKeepsFullQualityWhenConditionsAreHealthy),
            ("critical thermal state pauses playback", testCriticalThermalStatePausesPlayback),
            ("mirrored strategy assigns all displays", testMirroredStrategyAssignsSelectedWallpaperToAllDisplays),
            ("explicit strategy uses per-display assignments", testExplicitStrategyUsesPerDisplayAssignments),
            ("explicit strategy drops displays without fallback", testExplicitStrategyDropsDisplaysWithoutAssignmentOrFallback),
            ("assignment normalizer seeds defaults for empty state", testAssignmentNormalizerSeedsDefaultsForEmptyState),
            ("assignment normalizer drops stale displays and wallpapers", testAssignmentNormalizerDropsStaleDisplaysAndWallpapers),
        ]

        var failures: [String] = []

        for (name, test) in tests {
            do {
                try test()
                print("PASS \(name)")
            } catch {
                failures.append("\(name): \(error)")
                print("FAIL \(name): \(error)")
            }
        }

        if !failures.isEmpty {
            throw TestSuiteFailure(details: failures)
        }

        print("All core tests passed.")
    }
}

private struct TestSuiteFailure: Error, CustomStringConvertible {
    let details: [String]

    var description: String {
        details.joined(separator: "\n")
    }
}

private struct ExpectationFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw ExpectationFailure(message: message)
    }
}

private func expectContains<T: Equatable>(_ collection: [T], _ element: T, _ message: String) throws {
    try expect(collection.contains(element), message)
}

private func makeManifest() -> WallpaperManifest {
    WallpaperManifest(
        id: "aurora",
        version: 1,
        title: "Aurora",
        summary: "Gradient wallpaper",
        creator: WallpaperManifest.Creator(id: "studio", displayName: "Studio"),
        tags: ["gradient", "ambient"],
        category: "Featured",
        contentRating: .general,
        video: WallpaperManifest.VideoAsset(
            fileName: "wallpaper.mp4",
            previewImageFileName: "preview.jpg",
            container: .mp4,
            codec: .hevc,
            width: 3840,
            height: 2160,
            frameRate: 30,
            durationSeconds: 45
        ),
        checksums: [
            WallpaperManifest.Checksum(
                fileName: "wallpaper.mp4",
                sha256: String(repeating: "a", count: 64)
            ),
            WallpaperManifest.Checksum(
                fileName: "preview.jpg",
                sha256: String(repeating: "b", count: 64)
            ),
        ]
    )
}

private func testValidManifestProducesNoIssues() throws {
    let manifest = makeManifest()
    let validator = WallpaperPackageValidator()

    let issues = validator.validate(
        manifest: manifest,
        availableFiles: ["manifest.json", "wallpaper.mp4", "preview.jpg"],
        totalPackageSizeInBytes: 120 * 1_024 * 1_024
    )

    try expect(issues.isEmpty, "Expected no validation issues, got \(issues)")
}

private func testValidatorFlagsMissingFilesAndUnexpectedEntries() throws {
    let manifest = makeManifest()
    let validator = WallpaperPackageValidator()

    let issues = validator.validate(
        manifest: manifest,
        availableFiles: ["manifest.json", "wallpaper.mp4", "script.sh"],
        totalPackageSizeInBytes: 120 * 1_024 * 1_024
    )

    try expectContains(issues, .missingRequiredFile("preview.jpg"), "Expected missing preview issue.")
    try expectContains(issues, .unexpectedFile("script.sh"), "Expected unexpected file issue.")
}

private func testValidatorRejectsUnexpectedChecksummedFiles() throws {
    let manifest = WallpaperManifest(
        id: "aurora",
        version: 1,
        title: "Aurora",
        summary: "Gradient wallpaper",
        creator: WallpaperManifest.Creator(id: "studio", displayName: "Studio"),
        tags: ["gradient", "ambient"],
        category: "Featured",
        contentRating: .general,
        video: WallpaperManifest.VideoAsset(
            fileName: "wallpaper.mp4",
            previewImageFileName: "preview.jpg",
            container: .mp4,
            codec: .hevc,
            width: 3840,
            height: 2160,
            frameRate: 30,
            durationSeconds: 45
        ),
        checksums: [
            WallpaperManifest.Checksum(
                fileName: "wallpaper.mp4",
                sha256: String(repeating: "a", count: 64)
            ),
            WallpaperManifest.Checksum(
                fileName: "preview.jpg",
                sha256: String(repeating: "b", count: 64)
            ),
            WallpaperManifest.Checksum(
                fileName: "script.sh",
                sha256: String(repeating: "c", count: 64)
            ),
        ]
    )
    let validator = WallpaperPackageValidator()

    let issues = validator.validate(
        manifest: manifest,
        availableFiles: ["manifest.json", "wallpaper.mp4", "preview.jpg", "script.sh"]
    )

    try expectContains(issues, .unexpectedFile("script.sh"), "Expected checksummed extra file to remain invalid.")
}

private func testValidatorFlagsMetadataAndChecksumProblems() throws {
    let manifest = WallpaperManifest(
        id: "bad",
        version: 0,
        title: " ",
        summary: String(repeating: "x", count: 400),
        creator: WallpaperManifest.Creator(id: "creator", displayName: "Creator"),
        tags: ["ambient", ""],
        category: "Featured",
        contentRating: .general,
        video: WallpaperManifest.VideoAsset(
            fileName: "wallpaper.mp4",
            previewImageFileName: "preview.gif",
            container: .mov,
            codec: .h264,
            width: 0,
            height: 1080,
            frameRate: 0,
            durationSeconds: -1
        ),
        checksums: [
            WallpaperManifest.Checksum(fileName: "wallpaper.mp4", sha256: "invalid"),
        ]
    )
    let validator = WallpaperPackageValidator(
        constraints: WallpaperPackageConstraints(maximumPackageSizeInBytes: 10)
    )

    let issues = validator.validate(
        manifest: manifest,
        availableFiles: ["manifest.json", "wallpaper.mp4", "preview.gif"],
        totalPackageSizeInBytes: 11
    )

    try expectContains(issues, .invalidVersion, "Expected invalid version issue.")
    try expectContains(issues, .titleEmpty, "Expected title empty issue.")
    try expectContains(issues, .summaryTooLong(400), "Expected summary too long issue.")
    try expectContains(issues, .emptyTag, "Expected empty tag issue.")
    try expectContains(issues, .invalidDimensions, "Expected invalid dimensions issue.")
    try expectContains(issues, .invalidFrameRate, "Expected invalid frame rate issue.")
    try expectContains(issues, .invalidDuration, "Expected invalid duration issue.")
    try expectContains(issues, .unsupportedPreviewImage("preview.gif"), "Expected preview format issue.")
    try expectContains(issues, .mismatchedVideoContainer("wallpaper.mp4"), "Expected mismatched video container issue.")
    try expectContains(issues, .missingChecksum("preview.gif"), "Expected missing checksum issue.")
    try expectContains(issues, .invalidChecksumFormat("wallpaper.mp4"), "Expected invalid checksum issue.")
    try expectContains(issues, .packageTooLarge(11), "Expected package too large issue.")
}

private func testFullscreenAppPausesPlayback() throws {
    let engine = PlaybackPolicyEngine()

    let policy = engine.evaluate(
        context: PlaybackContext(
            powerSource: .ac,
            thermalState: .nominal,
            isLowPowerModeEnabled: false,
            hasFullscreenApp: true,
            userPreference: .automatic
        )
    )

    try expect(policy.action == .pause, "Expected fullscreen app to pause playback.")
    try expect(policy.reasons == [.fullscreenAppActive], "Expected fullscreen pause reason.")
}

private func testBatteryAndLowPowerReducePlayback() throws {
    let engine = PlaybackPolicyEngine()

    let policy = engine.evaluate(
        context: PlaybackContext(
            powerSource: .battery,
            thermalState: .fair,
            isLowPowerModeEnabled: true,
            hasFullscreenApp: false,
            userPreference: .automatic
        )
    )

    try expect(policy.action == .play, "Expected playback to continue.")
    try expect(policy.quality == .reduced, "Expected reduced playback quality.")
    try expectContains(policy.reasons, .lowPowerModeEnabled, "Expected Low Power Mode reason.")
    try expectContains(policy.reasons, .onBatteryPower, "Expected battery reason.")
}

private func testQualityPreferenceKeepsFullQualityWhenConditionsAreHealthy() throws {
    let engine = PlaybackPolicyEngine()

    let policy = engine.evaluate(
        context: PlaybackContext(
            powerSource: .battery,
            thermalState: .nominal,
            isLowPowerModeEnabled: false,
            hasFullscreenApp: false,
            userPreference: .prioritizeQuality
        )
    )

    try expect(policy.action == .play, "Expected playback to continue.")
    try expect(policy.quality == .full, "Expected full quality playback.")
    try expect(policy.reasons == [.prioritizeQuality], "Expected quality preference reason.")
}

private func testCriticalThermalStatePausesPlayback() throws {
    let engine = PlaybackPolicyEngine()

    let policy = engine.evaluate(
        context: PlaybackContext(
            powerSource: .ac,
            thermalState: .critical,
            isLowPowerModeEnabled: false,
            hasFullscreenApp: false,
            userPreference: .automatic
        )
    )

    try expect(policy.action == .pause, "Expected critical thermal state to pause playback.")
    try expect(policy.reasons == [.criticalThermalState], "Expected critical thermal reason.")
}

private func testMirroredStrategyAssignsSelectedWallpaperToAllDisplays() throws {
    let planner = DisplayAssignmentPlanner()

    let assignments = planner.plan(
        activeDisplays: ["Built-in", "Studio"],
        strategy: .mirrored(wallpaperID: "aurora")
    )

    try expect(
        assignments == [
            DisplayAssignment(displayID: "Built-in", wallpaperID: "aurora"),
            DisplayAssignment(displayID: "Studio", wallpaperID: "aurora"),
        ],
        "Expected mirrored assignments for both displays."
    )
}

private func testExplicitStrategyUsesPerDisplayAssignments() throws {
    let planner = DisplayAssignmentPlanner()

    let assignments = planner.plan(
        activeDisplays: ["Built-in", "Studio", "Projector"],
        strategy: .explicit(
            assignments: [
                "Built-in": "aurora",
                "Studio": "night-grid",
            ],
            fallbackWallpaperID: "forest-rain"
        )
    )

    try expect(
        assignments == [
            DisplayAssignment(displayID: "Built-in", wallpaperID: "aurora"),
            DisplayAssignment(displayID: "Studio", wallpaperID: "night-grid"),
            DisplayAssignment(displayID: "Projector", wallpaperID: "forest-rain"),
        ],
        "Expected explicit assignments with fallback."
    )
}

private func testExplicitStrategyDropsDisplaysWithoutAssignmentOrFallback() throws {
    let planner = DisplayAssignmentPlanner()

    let assignments = planner.plan(
        activeDisplays: ["Built-in", "Studio"],
        strategy: .explicit(
            assignments: ["Built-in": "aurora"],
            fallbackWallpaperID: nil
        )
    )

    try expect(
        assignments == [DisplayAssignment(displayID: "Built-in", wallpaperID: "aurora")],
        "Expected unassigned displays to be omitted without a fallback wallpaper."
    )
}

private func testAssignmentNormalizerSeedsDefaultsForEmptyState() throws {
    let normalizer = ExplicitDisplayAssignmentNormalizer()

    let assignments = normalizer.normalize(
        activeDisplays: ["Built-in", "Studio"],
        currentAssignments: [:],
        availableWallpaperIDs: ["aurora", "night-grid"]
    )

    try expect(
        assignments == [
            "Built-in": "aurora",
            "Studio": "aurora",
        ],
        "Expected empty assignment state to use the first available wallpaper for each display."
    )
}

private func testAssignmentNormalizerDropsStaleDisplaysAndWallpapers() throws {
    let normalizer = ExplicitDisplayAssignmentNormalizer()

    let assignments = normalizer.normalize(
        activeDisplays: ["Built-in", "Studio"],
        currentAssignments: [
            "Built-in": "aurora",
            "Old Display": "night-grid",
            "Studio": "missing-wallpaper",
        ],
        availableWallpaperIDs: ["aurora", "forest-rain"]
    )

    try expect(
        assignments == [
            "Built-in": "aurora",
            "Studio": "aurora",
        ],
        "Expected inactive displays and unknown wallpapers to be dropped before defaults are filled in."
    )
}
