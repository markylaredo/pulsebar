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
    private static let minimumWindowSize = NSSize(width: 880, height: 540)

    private let monitor: SystemMonitor
    private let lifecycle = SystemExplorerLifecycle()
    private var contentController: NSViewController?

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
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("PulseBarSystemOverview")
        window.minSize = Self.minimumWindowSize

        // AppKit can restore a frame saved by an older release even when it is
        // smaller than the current minimum. Clamp it after autosave restoration
        // so the split view never reopens as a collapsed toolbar-only window.
        Self.enforceMinimumFrame(on: window)
        super.init(window: window)
        window.delegate = self
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
        window.minSize = Self.minimumWindowSize
        Self.enforceMinimumFrame(on: window)
    }

    func windowWillClose(_ notification: Notification) {
        lifecycle.setVisible(false)
        // A retained NSWindow also retains its SwiftUI hierarchy. Detaching the
        // content releases page view models, chart renderers, and detailed monitor
        // tasks while preserving the inexpensive window object for fast reopening.
        guard let window else { return }
        let frame = window.frame
        window.contentView = nil
        contentController = nil
        window.setFrame(frame, display: false)
    }

    private func installContentIfNeeded() {
        guard let window, contentController == nil else { return }
        let restoredFrame = window.frame
        let hostingController = NSHostingController(
            rootView: OverviewRootView(monitor: monitor, lifecycle: lifecycle)
        )
        // The explorer window owns its size. Letting NSHostingController derive a
        // preferred size from NavigationSplitView can asynchronously collapse the
        // window to the toolbar's intrinsic size after it is installed.
        hostingController.sizingOptions = []
        let containerView = NSView(
            frame: NSRect(origin: .zero, size: window.contentLayoutRect.size)
        )
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        contentController = hostingController
        // Install the hosting view directly. NSWindow's contentViewController
        // integration follows preferredContentSize and can shrink a split view to
        // its toolbar's intrinsic size even when the window has a larger saved frame.
        window.contentView = containerView
        window.minSize = Self.minimumWindowSize
        window.setFrame(restoredFrame, display: false)
        Self.enforceMinimumFrame(on: window)
    }

    private static func enforceMinimumFrame(on window: NSWindow) {
        guard window.frame.width < minimumWindowSize.width
                || window.frame.height < minimumWindowSize.height else { return }

        var frame = window.frame
        let topEdge = frame.maxY
        frame.size.width = max(frame.width, minimumWindowSize.width)
        frame.size.height = max(frame.height, minimumWindowSize.height)
        frame.origin.y = topEdge - frame.height
        if let screen = window.screen ?? NSScreen.main {
            frame = window.constrainFrameRect(frame, to: screen)
        }
        window.setFrame(frame, display: false)
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
