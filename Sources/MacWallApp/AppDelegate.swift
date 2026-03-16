import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sessionDidBecomeActiveObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var screensaverStopObserver: NSObjectProtocol?
    private var screenLockObserver: NSObjectProtocol?
    private var screenUnlockObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var launchReassertWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureLaunchAtLoginEnabled()
        setupObservers()
        scheduleLaunchReassertion()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tearDownObservers()
    }

    private func setupObservers() {
        if sessionDidBecomeActiveObserver == nil {
            sessionDidBecomeActiveObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSessionDidBecomeActiveNotification()
                }
            }
        }

        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleWakeNotification()
                }
            }
        }

        if screensaverStopObserver == nil {
            screensaverStopObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.screensaver.didstop"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreensaverStopNotification()
                }
            }
        }

        if screenLockObserver == nil {
            screenLockObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenLockNotification()
                }
            }
        }

        if screenUnlockObserver == nil {
            screenUnlockObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenUnlockNotification()
                }
            }
        }

        if screenParametersObserver == nil {
            screenParametersObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenParametersChangeNotification()
                }
            }
        }
    }

    private func ensureLaunchAtLoginEnabled() {
        guard #available(macOS 13.0, *) else {
            return
        }

        guard isLaunchAtLoginRegistrationSupported else {
            return
        }

        let service = SMAppService.mainApp
        guard service.status != .enabled else {
            return
        }

        do {
            try service.register()
        } catch {
            NSLog("MacWall launch-at-login registration failed: %@", String(describing: error))
        }
    }

    private var isLaunchAtLoginRegistrationSupported: Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              bundleIdentifier.isEmpty == false else {
            return false
        }

        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard bundleURL.pathExtension == "app" else {
            return false
        }

        let applicationRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true),
        ].map { $0.resolvingSymlinksInPath().path + "/" }

        return applicationRoots.contains { rootPath in
            bundleURL.path.hasPrefix(rootPath)
        }
    }

    private func tearDownObservers() {
        launchReassertWorkItem?.cancel()
        launchReassertWorkItem = nil

        if let sessionDidBecomeActiveObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sessionDidBecomeActiveObserver)
            self.sessionDidBecomeActiveObserver = nil
        }

        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }

        if let screensaverStopObserver {
            DistributedNotificationCenter.default().removeObserver(screensaverStopObserver)
            self.screensaverStopObserver = nil
        }

        if let screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(screenLockObserver)
            self.screenLockObserver = nil
        }

        if let screenUnlockObserver {
            DistributedNotificationCenter.default().removeObserver(screenUnlockObserver)
            self.screenUnlockObserver = nil
        }

        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
    }

    private func scheduleLaunchReassertion() {
        launchReassertWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleLaunchReassertion()
            }
        }

        launchReassertWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func handleLaunchReassertion() {
        LockScreenAerialService.shared.reapply()
        DesktopRendererService.shared.reorderWindows()
    }

    private func handleSessionDidBecomeActiveNotification() {
        LockScreenAerialService.shared.reapply()
        DesktopRendererService.shared.reorderWindows()
        scheduleLaunchReassertion()
    }

    private func handleWakeNotification() {
        LockScreenAerialService.shared.reapply()
        DesktopRendererService.shared.reorderWindows()
    }

    private func handleScreensaverStopNotification() {
        DesktopRendererService.shared.reorderWindows()
    }

    private func handleScreenLockNotification() {
        launchReassertWorkItem?.cancel()
    }

    private func handleScreenUnlockNotification() {
        LockScreenAerialService.shared.reapply()
        DesktopRendererService.shared.reorderWindows()
        scheduleLaunchReassertion()
    }

    private func handleScreenParametersChangeNotification() {
        DesktopRendererService.shared.reorderWindows()
    }
}
