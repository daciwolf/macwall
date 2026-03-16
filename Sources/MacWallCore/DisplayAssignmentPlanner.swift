public struct DisplayAssignment: Equatable, Identifiable, Sendable {
    public let displayID: String
    public let wallpaperID: String

    public init(displayID: String, wallpaperID: String) {
        self.displayID = displayID
        self.wallpaperID = wallpaperID
    }

    public var id: String {
        displayID
    }
}

public enum WallpaperAssignmentStrategy: Equatable, Sendable {
    case mirrored(wallpaperID: String)
    case explicit(assignments: [String: String], fallbackWallpaperID: String?)
}

public struct DisplayAssignmentPlanner: Sendable {
    public init() {}

    public func plan(
        activeDisplays: [String],
        strategy: WallpaperAssignmentStrategy
    ) -> [DisplayAssignment] {
        switch strategy {
        case let .mirrored(wallpaperID):
            return activeDisplays.map { displayID in
                DisplayAssignment(displayID: displayID, wallpaperID: wallpaperID)
            }

        case let .explicit(assignments, fallbackWallpaperID):
            return activeDisplays.compactMap { displayID in
                guard let wallpaperID = assignments[displayID] ?? fallbackWallpaperID else {
                    return nil
                }

                return DisplayAssignment(displayID: displayID, wallpaperID: wallpaperID)
            }
        }
    }
}
