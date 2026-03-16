public struct ExplicitDisplayAssignmentNormalizer: Sendable {
    public init() {}

    public func normalize(
        activeDisplays: [String],
        currentAssignments: [String: String],
        availableWallpaperIDs: [String]
    ) -> [String: String] {
        let activeDisplayIDs = Set(activeDisplays)
        let availableWallpaperIDSet = Set(availableWallpaperIDs)
        let fallbackWallpaperID = availableWallpaperIDs.first

        var normalizedAssignments = currentAssignments.filter { displayID, wallpaperID in
            activeDisplayIDs.contains(displayID) && availableWallpaperIDSet.contains(wallpaperID)
        }

        for displayID in activeDisplays where normalizedAssignments[displayID] == nil {
            guard let fallbackWallpaperID else {
                continue
            }

            normalizedAssignments[displayID] = fallbackWallpaperID
        }

        return normalizedAssignments
    }
}
