import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class SystemExplorerLifecycle {
    private(set) var isVisible = false

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
    }
}

@MainActor
final class OverviewWindowController: NSWindowController, NSWindowDelegate {
    private let monitor: SystemMonitor
    private let lifecycle = SystemExplorerLifecycle()

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PulseBar"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 880, height: 540)
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("PulseBarSystemOverview")
        super.init(window: window)
        window.delegate = self
        installContentIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        lifecycle.setVisible(true)
        installContentIfNeeded()
        NSApplication.shared.activate()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        lifecycle.setVisible(false)
        // A retained NSWindow also retains its SwiftUI hierarchy. Detaching the
        // content releases page view models, chart renderers, and detailed monitor
        // tasks while preserving the inexpensive window object for fast reopening.
        window?.contentViewController = nil
    }

    private func installContentIfNeeded() {
        guard let window, window.contentViewController == nil else { return }
        window.contentViewController = NSHostingController(
            rootView: OverviewRootView(monitor: monitor, lifecycle: lifecycle)
        )
    }
}

private struct OverviewRootView: View {
    let monitor: SystemMonitor
    let lifecycle: SystemExplorerLifecycle
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue

    var body: some View {
        SystemExplorerView()
            .environment(monitor)
            .environment(lifecycle)
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
