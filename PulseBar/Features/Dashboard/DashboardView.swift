import AppKit
import SwiftUI

struct DashboardView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.networkDisplayMode) private var networkDisplayModeRaw = NetworkDisplayMode.data.rawValue
    @AppStorage(SettingsKey.dashboardLiquidGlass) private var dashboardLiquidGlass = true
    @AppStorage(SettingsKey.dashboardBackgroundTint) private var dashboardBackgroundTintRaw = DashboardBackgroundTint.black.rawValue
    @AppStorage(SettingsKey.dashboardOpacity) private var dashboardOpacity = DashboardAppearance.defaultOpacityLevel
    @AppStorage(SettingsKey.dashboardPinned) private var dashboardPinned = true
    @State private var isPerCoreExpanded = false
    let openOverviewAction: (() -> Void)?
    let openSettingsAction: (() -> Void)?
    let dashboardPinAction: ((Bool) -> Void)?

    init(
        openOverviewAction: (() -> Void)? = nil,
        openSettingsAction: (() -> Void)? = nil,
        dashboardPinAction: ((Bool) -> Void)? = nil
    ) {
        self.openOverviewAction = openOverviewAction
        self.openSettingsAction = openSettingsAction
        self.dashboardPinAction = dashboardPinAction
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 13) {
                    cpuSection
                    Divider()
                    memorySection
                    Divider()
                    networkSection
                    Divider()
                    diskSection
                    Divider()
                    storageSection
                    if let battery = monitor.metrics.battery {
                        Divider()
                        batterySection(battery)
                    }
                    Divider()
                    thermalSection
                }
                .padding(14)
            }
        }
        .frame(width: 360, height: 570)
        .background { dashboardSurface }
    }

    @ViewBuilder
    private var dashboardSurface: some View {
        if dashboardLiquidGlass {
            // NSPopover supplies the system Liquid Glass surface on macOS 26.
            // Keep this layer transparent so it does not cover that material.
            dashboardTint.opacity(dashboardTintOpacity)
        } else {
            Color.black
        }
    }

    private var dashboardTint: Color {
        (DashboardBackgroundTint(rawValue: dashboardBackgroundTintRaw) ?? .black).color
    }

    private var dashboardTintOpacity: Double {
        DashboardAppearance.glassTintOpacity(for: dashboardOpacity)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PulseBar").font(.headline)
                Text(machineDescription).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { openOverviewAction?() } label: {
                Image(systemName: "rectangle.grid.2x2")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open System Overview")
            .accessibilityLabel("Open System Overview")
            .keyboardShortcut("o", modifiers: .command)
            .disabled(openOverviewAction == nil)
            Toggle(isOn: Binding(
                get: { dashboardPinned },
                set: { isPinned in
                    dashboardPinned = isPinned
                    dashboardPinAction?(isPinned)
                }
            )) {
                Image(systemName: dashboardPinned ? "pin.fill" : "pin")
                    .foregroundStyle(dashboardPinned ? Color.accentColor : .primary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .help(dashboardPinned
                  ? "Unpin Dashboard — close when clicking elsewhere"
                  : "Pin Dashboard — keep open when clicking elsewhere")
            .accessibilityLabel(dashboardPinned ? "Unpin Dashboard" : "Pin Dashboard")
            .accessibilityValue(dashboardPinned ? "Pinned" : "Unpinned")
            Button { showSettings() } label: {
                Image(systemName: "gearshape")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open PulseBar Settings")
            .accessibilityLabel("Open Settings")
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(14)
    }

    private var cpuSection: some View {
        MetricSection(title: "CPU", value: MetricFormatter.percentage(monitor.metrics.cpu.totalUsage)) {
            ProgressView(value: monitor.metrics.cpu.totalUsage).tint(.blue)
            MiniChart(samples: monitor.histories.cpu.samples, color: .blue).frame(height: 34)
            if !monitor.metrics.cpu.loadAverages.isEmpty {
                Text("\(monitor.metrics.cpu.logicalCoreCount) logical cores · Load  " + monitor.metrics.cpu.loadAverages.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            if !monitor.metrics.cpu.coreUsage.isEmpty {
                Button(action: togglePerCoreUtilization) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isPerCoreExpanded ? 90 : 0))
                        Text("Per-core utilization")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.caption)
                .accessibilityValue(isPerCoreExpanded ? "Expanded" : "Collapsed")

                if isPerCoreExpanded {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(Array(monitor.metrics.cpu.coreUsage.enumerated()), id: \.offset) { index, usage in
                            HStack {
                                Text("Core \(index + 1)").foregroundStyle(.secondary)
                                Spacer()
                                Text(MetricFormatter.percentage(usage)).monospacedDigit()
                            }
                            .font(.caption2)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var memorySection: some View {
        let memory = monitor.metrics.memory
        return MetricSection(title: "Memory", value: "\(MetricFormatter.memory(memory.used)) / \(MetricFormatter.memory(memory.physical))") {
            ProgressView(value: memory.usage).tint(.purple)
            MiniChart(samples: monitor.histories.memory.samples, color: .purple).frame(height: 30)
            LazyVGrid(columns: memoryDetailColumns, alignment: .leading, spacing: 6) {
                detail("App Memory", memory.appMemory)
                detail("Wired", memory.wired)
                detail("Compressed", memory.compressed)
                detail("Cached", memory.cached)
                detail("Swap", memory.swapUsed)
            }
        }
    }

    private var networkSection: some View {
        let network = monitor.metrics.network
        return MetricSection(title: "Network", value: "") {
            Picker("Network graph", selection: $networkDisplayModeRaw) {
                ForEach(NetworkDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            HStack {
                networkRate("arrow.down", incomingNetworkRate, .green)
                Spacer()
                networkRate("arrow.up", outgoingNetworkRate, .orange)
            }
            MiniChart(
                samples: incomingNetworkSamples,
                color: .green,
                secondarySamples: outgoingNetworkSamples,
                secondaryColor: .orange
            )
            .frame(height: 30)
            HStack(alignment: .top, spacing: 10) {
                networkSummary(title: "PACKETS", rows: [
                    ("In", MetricFormatter.count(network.totalPacketsReceived)),
                    ("Out", MetricFormatter.count(network.totalPacketsSent)),
                    ("In/sec", MetricFormatter.count(UInt64(max(0, network.packetsReceivedRate).rounded()))),
                    ("Out/sec", MetricFormatter.count(UInt64(max(0, network.packetsSentRate).rounded())))
                ])
                Divider().frame(height: 68)
                networkSummary(title: "DATA", rows: [
                    ("Received", MetricFormatter.bytes(network.totalReceived)),
                    ("Sent", MetricFormatter.bytes(network.totalTransmitted)),
                    ("Received/sec", MetricFormatter.rate(network.downloadRate)),
                    ("Sent/sec", MetricFormatter.rate(network.uploadRate))
                ])
            }
        }
    }

    private var diskSection: some View {
        MetricSection(title: "Disk", value: "") {
            HStack {
                rate("arrow.down", monitor.metrics.disk.readRate, .cyan)
                Spacer()
                rate("arrow.up", monitor.metrics.disk.writeRate, .indigo)
            }
            Text("Totals  Read \(MetricFormatter.bytes(monitor.metrics.disk.totalRead)) · Written \(MetricFormatter.bytes(monitor.metrics.disk.totalWritten))")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private var storageSection: some View {
        let storage = monitor.metrics.storage
        return MetricSection(title: "Storage", value: MetricFormatter.percentage(storage.usage)) {
            ProgressView(value: storage.usage).tint(.teal)
            Text("\(MetricFormatter.bytes(storage.used)) used · \(MetricFormatter.bytes(storage.available)) available")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func batterySection(_ battery: BatteryStats) -> some View {
        MetricSection(title: "Battery", value: MetricFormatter.percentage(battery.percentage)) {
            ProgressView(value: battery.percentage).tint(battery.percentage < 0.2 ? .red : .green)
            Text(battery.isCharging ? "Charging" : battery.isConnectedToPower ? "Connected to power" : remainingTime(battery))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var thermalSection: some View {
        MetricSection(title: "Thermal", value: monitor.metrics.thermal.rawValue) {
            Text(thermalDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func detail(_ title: String, _ value: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 1) { Text(title).foregroundStyle(.secondary); Text(MetricFormatter.memory(value)).monospacedDigit() }
            .font(.caption)
    }

    private func rate(_ symbol: String, _ value: Double, _ color: Color) -> some View {
        Label(MetricFormatter.rate(value), systemImage: symbol).font(.subheadline).monospacedDigit().foregroundStyle(color)
    }

    private func networkRate(_ symbol: String, _ value: Double, _ color: Color) -> some View {
        let text = networkDisplayMode == .data ? MetricFormatter.rate(value) : MetricFormatter.packetRate(value)
        return Label(text, systemImage: symbol)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(color)
    }

    private func networkSummary(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.bold()).foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    Text(row.0).foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(row.1).monospacedDigit()
                }
                .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var networkDisplayMode: NetworkDisplayMode {
        NetworkDisplayMode(rawValue: networkDisplayModeRaw) ?? .data
    }

    private var incomingNetworkRate: Double {
        networkDisplayMode == .data ? monitor.metrics.network.downloadRate : monitor.metrics.network.packetsReceivedRate
    }

    private var outgoingNetworkRate: Double {
        networkDisplayMode == .data ? monitor.metrics.network.uploadRate : monitor.metrics.network.packetsSentRate
    }

    private var incomingNetworkSamples: [Double] {
        networkDisplayMode == .data ? monitor.histories.download.samples : monitor.histories.packetsReceived.samples
    }

    private var outgoingNetworkSamples: [Double] {
        networkDisplayMode == .data ? monitor.histories.upload.samples : monitor.histories.packetsSent.samples
    }

    private func remainingTime(_ battery: BatteryStats) -> String {
        guard let minutes = battery.timeRemainingMinutes else { return "On battery" }
        return "\(minutes / 60) hr \(minutes % 60) min remaining"
    }

    private func togglePerCoreUtilization() {
        if reduceMotion {
            isPerCoreExpanded.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                isPerCoreExpanded.toggle()
            }
        }
    }

    private var thermalDescription: String {
        switch monitor.metrics.thermal {
        case .nominal: "System performance is normal"
        case .fair: "Thermal pressure is elevated"
        case .serious: "Performance may be reduced"
        case .critical: "Thermal pressure is critical"
        }
    }

    private var machineDescription: String {
        "\(monitor.machineInfo.name) · \(monitor.machineInfo.processor) · \(MetricFormatter.memory(monitor.machineInfo.physicalMemory))"
    }

    private var memoryDetailColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)
    }

    private func showSettings() {
        if let openSettingsAction {
            openSettingsAction()
            return
        }
        openSettings()
        Task { @MainActor in
            await SettingsWindowPresenter.bringToFront()
        }
    }
}

@MainActor
private enum SettingsWindowPresenter {
    static func bringToFront() async {
        for _ in 0..<4 {
            if let window = settingsWindow {
                NSApplication.shared.activate()
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static var settingsWindow: NSWindow? {
        NSApplication.shared.windows.first { window in
            window.styleMask.contains(.titled)
                && window.styleMask.contains(.closable)
                && !window.styleMask.contains(.nonactivatingPanel)
        }
    }
}
