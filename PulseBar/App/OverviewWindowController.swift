import AppKit
import SwiftUI

@MainActor
final class OverviewWindowController: NSWindowController {
    init(monitor: SystemMonitor) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PulseBar"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 500)
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("PulseBarSystemOverview")
        window.contentViewController = NSHostingController(
            rootView: OverviewRootView(monitor: monitor)
        )
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

private struct OverviewRootView: View {
    let monitor: SystemMonitor
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue

    var body: some View {
        SystemExplorerView()
            .environment(monitor)
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
