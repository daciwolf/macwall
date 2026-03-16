import Foundation

extension URL {
    var macWallFileSystemPath: String {
        guard isFileURL else {
            return path
        }

        return withUnsafeFileSystemRepresentation { pointer in
            guard let pointer else {
                return path
            }

            return String(cString: pointer)
        }
    }
}
