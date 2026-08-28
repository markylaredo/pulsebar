import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(monitor: SystemMonitor) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PulseBar Settings"
        window.contentMinSize = NSSize(width: 560, height: 460)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsRootView(monitor: monitor))
        window.setContentSize(NSSize(width: 620, height: 520))
        window.center()
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
