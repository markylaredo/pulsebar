import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = SystemMonitor()

    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--unregister-login-item") {
            unregisterLoginItemAndQuit()
            return
        }

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

    private func unregisterLoginItemAndQuit() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        }
        NSApplication.shared.terminate(nil)
    }
}
