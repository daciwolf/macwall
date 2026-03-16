import AppKit
import CoreGraphics
import Foundation

struct DisplayOption: Identifiable, Hashable {
    let id: String
    let name: String
}

enum DisplayCatalog {
    struct Entry {
        let id: String
        let name: String
        let screen: NSScreen
    }

    static func currentEntries() -> [Entry] {
        NSScreen.screens
            .sorted { lhs, rhs in
                if lhs.isMacWallBuiltInDisplay != rhs.isMacWallBuiltInDisplay {
                    return lhs.isMacWallBuiltInDisplay
                }

                let lhsFrame = lhs.frame.integral
                let rhsFrame = rhs.frame.integral
                if lhsFrame.minY != rhsFrame.minY {
                    return lhsFrame.minY > rhsFrame.minY
                }

                if lhsFrame.minX != rhsFrame.minX {
                    return lhsFrame.minX < rhsFrame.minX
                }

                return lhs.macWallDisplayName < rhs.macWallDisplayName
            }
            .map { screen in
                Entry(
                    id: screen.macWallDisplayID,
                    name: screen.macWallDisplayName,
                    screen: screen
                )
            }
    }

    static func currentOptions() -> [DisplayOption] {
        currentEntries().map { entry in
            DisplayOption(id: entry.id, name: entry.name)
        }
    }
}

private extension NSScreen {
    var macWallDisplayNumber: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    var macWallDisplayID: String {
        if let displayNumber = macWallDisplayNumber {
            return "display-\(displayNumber)"
        }

        let frame = frame.integral
        return "display-\(Int(frame.origin.x))-\(Int(frame.origin.y))-\(Int(frame.width))-\(Int(frame.height))"
    }

    var macWallDisplayName: String {
        if #available(macOS 12.0, *) {
            return localizedName
        }

        return "Display \(Int(frame.width))x\(Int(frame.height))"
    }

    var isMacWallBuiltInDisplay: Bool {
        guard let displayNumber = macWallDisplayNumber else {
            return false
        }

        return CGDisplayIsBuiltin(displayNumber) != 0
    }
}
