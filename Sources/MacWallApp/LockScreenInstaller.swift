import Foundation

enum LockScreenInstallerError: LocalizedError {
    case bundledSaverMissing

    var errorDescription: String? {
        switch self {
        case .bundledSaverMissing:
            return "MacWall could not find its bundled screen saver module."
        }
    }
}

struct LockScreenInstaller {
    private let fileManager = FileManager.default

    var installedSaverURL: URL {
        let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library", isDirectory: true)

        return libraryDirectory
            .appendingPathComponent("Screen Savers", isDirectory: true)
            .appendingPathComponent("MacWallScreenSaver.saver", isDirectory: true)
    }

    var isInstalled: Bool {
        fileManager.fileExists(atPath: installedSaverURL.path())
    }

    func installBundledSaver() throws {
        guard let sourceURL = bundledSaverURL() else {
            throw LockScreenInstallerError.bundledSaverMissing
        }

        let destinationDirectory = installedSaverURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try removeStaleInstallBundles(in: destinationDirectory)
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("MacWallScreenSaverInstall", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        let stagedURL = stagingDirectory
            .appendingPathComponent("MacWallScreenSaver-\(UUID().uuidString).saver", isDirectory: true)

        if fileManager.fileExists(atPath: stagedURL.path()) {
            try fileManager.removeItem(at: stagedURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: stagedURL)

            if fileManager.fileExists(atPath: installedSaverURL.path()) {
                try fileManager.removeItem(at: installedSaverURL)
            }

            try fileManager.moveItem(at: stagedURL, to: installedSaverURL)
        } catch {
            if fileManager.fileExists(atPath: stagedURL.path()) {
                try? fileManager.removeItem(at: stagedURL)
            }
            throw error
        }
    }

    func removeInstalledSaver() throws {
        guard fileManager.fileExists(atPath: installedSaverURL.path()) else {
            return
        }

        try fileManager.removeItem(at: installedSaverURL)
    }

    private func removeStaleInstallBundles(in directoryURL: URL) throws {
        let directoryContents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )

        for entryURL in directoryContents {
            let fileName = entryURL.lastPathComponent
            guard
                fileName.hasPrefix("MacWallScreenSaver-"),
                fileName.hasSuffix(".saver")
            else {
                continue
            }

            try? fileManager.removeItem(at: entryURL)
        }
    }

    private func bundledSaverURL() -> URL? {
        if let bundledResource = Bundle.main.url(forResource: "MacWallScreenSaver", withExtension: "saver") {
            return bundledResource
        }

        let siblingSaverURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("MacWallScreenSaver.saver", isDirectory: true)
        if fileManager.fileExists(atPath: siblingSaverURL.path()) {
            return siblingSaverURL
        }

        let distSaverURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("MacWallScreenSaver.saver", isDirectory: true)
        if fileManager.fileExists(atPath: distSaverURL.path()) {
            return distSaverURL
        }

        return nil
    }
}
