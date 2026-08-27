import AppKit
import SwiftUI

struct SystemInformationView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var model = SystemInformationViewModel()
    @State private var reportWasCopied = false

    var body: some View {
        ScrollView {
            if let system = model.system {
                VStack(alignment: .leading, spacing: 24) {
                    summary(system)
                    hardwareSection(system.hardware)
                    operatingSystemSection(system.operatingSystem)
                    displaysSection
                    batterySection
                    storageSection
                    networkSection
                }
                .frame(maxWidth: 840, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .top)
            } else if model.isLoading {
                ProgressView("Reading system information…")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                ContentUnavailableView(
                    "System information unavailable",
                    systemImage: "desktopcomputer.trianglebadge.exclamationmark",
                    description: Text("PulseBar could not read this Mac's system details.")
                )
                .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
        .defaultScrollAnchor(.top)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("System")
        .task { await model.run() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            model.refreshDisplays()
        }
    }

    private func summary(_ system: SystemInformationSnapshot) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(system.hardware.modelName)
                    .font(.largeTitle.weight(.semibold))
                Text("\(system.hardware.chip) · \(MetricFormatter.memory(system.hardware.physicalMemory)) · macOS \(system.operatingSystem.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(system.hardware.modelIdentifier) · \(system.hardware.architecture)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 7) {
                Button("Copy System Report", systemImage: "doc.on.doc") {
                    copyReport(system)
                }
                if reportWasCopied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func hardwareSection(_ hardware: HardwareInformation) -> some View {
        SystemInfoSection(title: "Hardware", symbol: "cpu") {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                SystemInfoRow(label: "Chip", value: hardware.chip)
                SystemInfoRow(label: "Architecture", value: hardware.architecture, monospaced: true)
                SystemInfoRow(label: "Memory", value: MetricFormatter.memory(hardware.physicalMemory))
                SystemInfoRow(label: "Logical CPUs", value: String(hardware.logicalProcessorCount), monospaced: true)
                SystemInfoRow(label: "Model Identifier", value: hardware.modelIdentifier, monospaced: true)
            }
        }
    }

    private func operatingSystemSection(_ operatingSystem: OperatingSystemInformation) -> some View {
        SystemInfoSection(title: "Operating System", symbol: "apple.logo") {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                SystemInfoRow(label: "macOS", value: operatingSystem.version)
                SystemInfoRow(label: "Build", value: operatingSystem.build, monospaced: true)
                SystemInfoRow(label: "Kernel", value: operatingSystem.kernel, monospaced: true)
                SystemInfoRow(label: "Computer Name", value: operatingSystem.computerName)
                SystemInfoRow(label: "Hostname", value: operatingSystem.hostname, monospaced: true)
                SystemInfoRow(label: "Last Boot", value: operatingSystem.bootDate.formatted(date: .abbreviated, time: .shortened))
                GridRow(alignment: .firstTextBaseline) {
                    Text("Uptime")
                        .foregroundStyle(.secondary)
                        .frame(width: 150, alignment: .leading)
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(MetricFormatter.uptime(ProcessInfo.processInfo.systemUptime))
                            .monospacedDigit()
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var displaysSection: some View {
        SystemInfoSection(title: "Displays", symbol: "display.2") {
            if model.displays.isEmpty {
                unavailable("Display details unavailable")
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(model.displays.enumerated()), id: \.element.id) { index, display in
                        if index > 0 { Divider() }
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 8) {
                                Text(display.name).font(.subheadline.weight(.semibold))
                                if display.isMain { statusLabel("Main", color: .blue) }
                                if display.isBuiltIn { statusLabel("Built-in", color: .secondary) }
                            }
                            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                                SystemInfoRow(label: "Resolution", value: "\(display.pixelWidth) × \(display.pixelHeight)", monospaced: true)
                                SystemInfoRow(label: "Scaled Resolution", value: "\(display.scaledWidth) × \(display.scaledHeight)", monospaced: true)
                                if let refreshRate = display.refreshRate {
                                    SystemInfoRow(label: "Refresh Rate", value: "\(refreshRate) Hz", monospaced: true)
                                }
                                SystemInfoRow(label: "HiDPI", value: display.isRetina ? "Yes" : "No")
                            }
                        }
                    }
                }
            }
        }
    }

    private var batterySection: some View {
        SystemInfoSection(title: "Battery", symbol: "battery.75percent") {
            if let battery = monitor.metrics.battery {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    SystemInfoRow(label: "Charge", value: MetricFormatter.percentage(battery.percentage))
                    SystemInfoRow(label: "Status", value: batteryStatus(battery))
                    SystemInfoRow(label: "Power Source", value: battery.isConnectedToPower ? "AC Power" : "Battery")
                    if let time = battery.timeRemainingMinutes {
                        SystemInfoRow(label: "Time Remaining", value: MetricFormatter.uptime(TimeInterval(time * 60)))
                    }
                    if let cycles = battery.cycleCount {
                        SystemInfoRow(label: "Cycle Count", value: String(cycles), monospaced: true)
                    }
                    if let condition = battery.condition {
                        SystemInfoRow(label: "Condition", value: condition)
                    }
                }
            } else {
                unavailable("No internal battery")
            }
        }
    }

    private var storageSection: some View {
        SystemInfoSection(title: "Storage", symbol: "internaldrive") {
            if monitor.volumes.isEmpty {
                unavailable("Storage information unavailable")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(monitor.volumes.enumerated()), id: \.element.id) { index, volume in
                        if index > 0 { Divider() }
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(volume.name).font(.subheadline.weight(.semibold))
                                if volume.isPrimary { statusLabel("Startup", color: .blue) }
                            }
                            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                                SystemInfoRow(label: "Capacity", value: formatted(volume.totalCapacity))
                                SystemInfoRow(label: "Used", value: formatted(volume.usedCapacity))
                                SystemInfoRow(label: "Available", value: formatted(volume.availableCapacity))
                                SystemInfoRow(label: "Filesystem", value: volume.filesystem ?? "Unavailable")
                            }
                        }
                    }
                }
            }
        }
    }

    private var networkSection: some View {
        SystemInfoSection(title: "Network Interfaces", symbol: "network") {
            if systemInterfaces.isEmpty {
                unavailable("Network information unavailable")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(systemInterfaces.enumerated()), id: \.element.id) { index, interface in
                        if index > 0 { Divider() }
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text(interface.displayName).font(.subheadline.weight(.semibold))
                                Text(interface.name).font(.caption.monospaced()).foregroundStyle(.secondary)
                                statusLabel(interface.status, color: interface.isActive ? .green : .secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                                SystemInfoRow(label: "Type", value: interface.kind.rawValue)
                                SystemInfoRow(label: "IPv4", value: interface.ipv4Addresses.joined(separator: ", ").nilIfEmpty ?? "Unavailable", monospaced: true)
                                SystemInfoRow(label: "IPv6", value: interface.ipv6Addresses.joined(separator: ", ").nilIfEmpty ?? "Unavailable", monospaced: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statusLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
    }

    private func unavailable(_ message: String) -> some View {
        Label(message, systemImage: "minus.circle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func formatted(_ value: UInt64?) -> String {
        value.map(MetricFormatter.bytes) ?? "Unavailable"
    }

    private func batteryStatus(_ battery: BatteryStats) -> String {
        if battery.isCharging { return "Charging" }
        if battery.isConnectedToPower { return "Connected to Power" }
        return "On Battery"
    }

    private var systemInterfaces: [NetworkInterfaceSnapshot] {
        model.interfaces.filter(\.isSystemRelevant)
    }

    private func copyReport(_ system: SystemInformationSnapshot) {
        let report = SystemReportFormatter.report(
            system: system,
            displays: model.displays,
            battery: monitor.metrics.battery,
            volumes: monitor.volumes,
            interfaces: model.interfaces,
            uptime: ProcessInfo.processInfo.systemUptime
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        reportWasCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            reportWasCopied = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
