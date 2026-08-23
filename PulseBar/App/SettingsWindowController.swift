import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(monitor: SystemMonitor) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PulseBar Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: SettingsRootView(monitor: monitor))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        NSApplication.shared.activate()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

private struct SettingsRootView: View {
    let monitor: SystemMonitor
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue

    var body: some View {
        SettingsView()
            .environment(monitor)
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
