import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let monitor: SystemMonitor
    private let openOverview: () -> Void
    private let openSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let labelModel: StatusItemLabelModel
    private var labelHostingView: NSHostingView<StatusItemLabel>?
    private var statusItemUpdateTask: Task<Void, Never>?
    private var statusItemLengthTask: Task<Void, Never>?
    private var defaultsObserver: NSObjectProtocol?
    private var globalShortcutController: GlobalShortcutController?

    init(
        monitor: SystemMonitor,
        openOverview: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.openOverview = openOverview
        self.openSettings = openSettings
        labelModel = StatusItemLabelModel(presentation: .make(metrics: monitor.metrics))
        super.init()
        globalShortcutController = GlobalShortcutController { [weak self] in
            Task { @MainActor in
                self?.togglePopover(nil)
            }
        }
        configureStatusItem()
        configurePopover()
        updateGlobalShortcut()
        observeMetrics()
        observeSettings()
        updateStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.title = ""
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])

        let hostingView = PassthroughHostingView(rootView: StatusItemLabel(model: labelModel))
        hostingView.frame = button.bounds.insetBy(dx: 6, dy: 0)
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)
        labelHostingView = hostingView
    }

    private func configurePopover() {
        updatePopoverBehavior()
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 570)
        popover.delegate = self
    }

    private func installPopoverContentIfNeeded() {
        guard popover.contentViewController == nil else { return }
        popover.contentViewController = NSHostingController(
            rootView: DashboardRootView(
                monitor: monitor,
                openOverview: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.openOverview()
                },
                openSettings: { [weak self] in
                    self?.openSettings()
                },
                dashboardPinChanged: { [weak self] isPinned in
                    self?.updatePopoverBehavior(isPinned: isPinned)
                }
            )
        )
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            installPopoverContentIfNeeded()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            button.state = .on
            NSApplication.shared.activate()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.state = .off
        // Swift Charts owns display-link threads while mounted. Release the hidden
        // dashboard hierarchy so a closed popover consumes no rendering budget.
        popover.contentViewController = nil
    }

    func shutdown() {
        statusItemUpdateTask?.cancel()
        statusItemLengthTask?.cancel()
        statusItemUpdateTask = nil
        statusItemLengthTask = nil
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
        globalShortcutController = nil
        popover.performClose(nil)
        popover.contentViewController = nil
    }

    private func updatePopoverBehavior() {
        let defaults = UserDefaults.standard
        let isPinned = defaults.object(forKey: SettingsKey.dashboardPinned) as? Bool ?? true
        updatePopoverBehavior(isPinned: isPinned)
    }

    private func updatePopoverBehavior(isPinned: Bool) {
        popover.behavior = isPinned ? .applicationDefined : .transient
    }

    private func updateGlobalShortcut() {
        let storedValue = UserDefaults.standard.string(forKey: SettingsKey.dashboardShortcut) ?? ""
        globalShortcutController?.register(DashboardShortcut(storageValue: storedValue))
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let presentation = MenuBarPresentation.make(metrics: monitor.metrics)
        button.toolTip = presentation.accessibilityLabel
        button.setAccessibilityLabel(presentation.accessibilityLabel)

        // Status items are cloned into every active menu bar by AppKit. Animating
        // each once-per-second value change keeps those offscreen layers rendering
        // continuously, so publish the current values in a non-animated transaction.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            labelModel.presentation = presentation
        }
        scheduleStatusItemLength(for: presentation)
    }

    private func scheduleStatusItemLength(for presentation: MenuBarPresentation) {
        let width: CGFloat
        switch presentation.widthBehavior {
        case .fixed:
            width = presentation.preferredWidth
        case .dynamic:
            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let textWidth = (presentation.text as NSString).size(withAttributes: [.font: font]).width
            let iconWidth = CGFloat(presentation.parts.compactMap(\.symbolName).count) * 19
            width = ceil(textWidth + iconWidth + 18)
        }

        statusItemLengthTask?.cancel()
        statusItemLengthTask = Task { @MainActor [weak self] in
            // NSStatusBarButton can be in the middle of an AppKit layout pass while
            // SwiftUI publishes the new label. Resize on the following run-loop turn
            // so the hosting view never asks its parent to lay out recursively.
            await Task.yield()
            guard !Task.isCancelled, let self else { return }
            guard abs(self.statusItem.length - width) > 0.5 else { return }
            self.statusItem.length = width
        }
    }

    private func observeMetrics() {
        withObservationTracking {
            _ = monitor.metrics
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeMetrics()
                self.scheduleStatusItemUpdate()
            }
        }
    }

    private func scheduleStatusItemUpdate() {
        statusItemUpdateTask?.cancel()
        statusItemUpdateTask = Task { @MainActor [weak self] in
            // Independent readers can finish a few milliseconds apart. Coalesce
            // those publications so AppKit redraws every display's clone once.
            do { try await Task.sleep(for: .milliseconds(75)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.updateStatusItem()
        }
    }

    private func observeSettings() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.statusItemUpdateTask?.cancel()
                self?.updatePopoverBehavior()
                self?.updateGlobalShortcut()
                self?.updateStatusItem()
            }
        }
    }
}

@MainActor
@Observable
private final class StatusItemLabelModel {
    var presentation: MenuBarPresentation

    init(presentation: MenuBarPresentation) {
        self.presentation = presentation
    }
}

private struct StatusItemLabel: View {
    @Bindable var model: StatusItemLabelModel

    var body: some View {
        HStack(spacing: 4) {
            if model.presentation.parts.isEmpty {
                Image(systemName: "waveform.path.ecg")
                Text("PulseBar")
            } else {
                HStack(spacing: 1) {
                    ForEach(Array(model.presentation.parts.enumerated()), id: \.element.id) { index, part in
                        if index > 0 {
                            Text("·")
                        }
                        HStack(spacing: 0) {
                            if let symbolName = part.symbolName {
                                Image(systemName: symbolName)
                                    .padding(.trailing, 3)
                            }
                            Text(part.prefix)
                            Text(part.value)
                        }
                        .frame(
                            width: model.presentation.widthBehavior == .fixed ? part.reservedWidth : nil,
                            alignment: .leading
                        )
                    }
                }
            }
        }
        .font(.system(size: NSFont.systemFontSize))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(model.presentation.accessibilityLabel)
    }
}

@MainActor
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct DashboardRootView: View {
    let monitor: SystemMonitor
    let openOverview: () -> Void
    let openSettings: () -> Void
    let dashboardPinChanged: (Bool) -> Void
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue

    var body: some View {
        DashboardView(
            openOverviewAction: openOverview,
            openSettingsAction: openSettings,
            dashboardPinAction: dashboardPinChanged
        )
            .environment(monitor)
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
