import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = SystemMonitor()

    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsWindowController = SettingsWindowController(monitor: monitor)
        self.settingsWindowController = settingsWindowController
        statusBarController = StatusBarController(
            monitor: monitor,
            openSettings: { [weak settingsWindowController] in
                settingsWindowController?.show()
            }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
