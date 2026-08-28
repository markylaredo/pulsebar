import SwiftUI

struct SystemExplorerView: View {
    @State private var selection = SystemExplorerDestination.overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Overview", systemImage: "gauge.with.dots.needle.67percent")
                    .tag(SystemExplorerDestination.overview)
                Label("Processes", systemImage: "list.bullet.rectangle")
                    .tag(SystemExplorerDestination.processes)
                Label("Performance", systemImage: "chart.xyaxis.line")
                    .tag(SystemExplorerDestination.performance)
                Label("Network", systemImage: "network")
                    .tag(SystemExplorerDestination.network)
                Label("Storage", systemImage: "internaldrive")
                    .tag(SystemExplorerDestination.storage)
                Label("System", systemImage: "desktopcomputer")
                    .tag(SystemExplorerDestination.system)
            }
            .listStyle(.sidebar)
            .navigationTitle("PulseBar")
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 210)
        } detail: {
            switch selection {
            case .overview:
                OverviewView()
            case .processes:
                ProcessListView()
            case .performance:
                PerformanceView()
            case .network:
                NetworkView()
            case .storage:
                StorageView()
            case .system:
                SystemInformationView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private enum SystemExplorerDestination: Hashable {
    case overview
    case processes
    case performance
    case network
    case storage
    case system
}

struct OverviewView: View {
    @Environment(SystemMonitor.self) private var monitor

    private let gridColumns = [
        GridItem(.adaptive(minimum: 245), spacing: 12, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                    cpuCard
                    memoryCard
                    networkCard
                    diskCard
                    thermalCard
                    uptimeCard
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .defaultScrollAnchor(.top)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Overview")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System Overview")
                .font(.largeTitle.weight(.semibold))
            Text(machineDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var cpuCard: some View {
        OverviewMetricCard(title: "CPU", symbol: "cpu", accent: .blue) {
            Text(MetricFormatter.percentage(monitor.metrics.cpu.totalUsage))
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()
            MiniChart(samples: recent(monitor.histories.cpu.samples), color: .blue)
                .frame(height: 48)
            Text("Total utilization")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var memoryCard: some View {
        let memory = monitor.metrics.memory
        return OverviewMetricCard(title: "Memory", symbol: "memorychip", accent: .purple) {
            Text("\(MetricFormatter.memory(memory.used)) / \(MetricFormatter.memory(memory.physical))")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(alignment: .firstTextBaseline) {
                Text(MetricFormatter.percentage(memory.usage))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text("used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            MiniChart(samples: recent(monitor.histories.memory.samples), color: .purple)
                .frame(height: 38)
        }
    }

    private var networkCard: some View {
        OverviewMetricCard(title: "Network", symbol: "network", accent: .green) {
            HStack(spacing: 12) {
                DirectionalMetricValue(
                    label: "Download",
                    symbol: "arrow.down",
                    value: MetricFormatter.rate(monitor.metrics.network.downloadRate),
                    color: .green
                )
                DirectionalMetricValue(
                    label: "Upload",
                    symbol: "arrow.up",
                    value: MetricFormatter.rate(monitor.metrics.network.uploadRate),
                    color: .orange
                )
            }
            MiniChart(
                samples: recent(monitor.histories.download.samples),
                color: .green,
                secondarySamples: recent(monitor.histories.upload.samples),
                secondaryColor: .orange
            )
            .frame(height: 45)
        }
    }

    private var diskCard: some View {
        OverviewMetricCard(title: "Disk Activity", symbol: "internaldrive", accent: .cyan) {
            HStack(spacing: 12) {
                DirectionalMetricValue(
                    label: "Read",
                    symbol: "arrow.down",
                    value: MetricFormatter.rate(monitor.metrics.disk.readRate),
                    color: .cyan
                )
                DirectionalMetricValue(
                    label: "Write",
                    symbol: "arrow.up",
                    value: MetricFormatter.rate(monitor.metrics.disk.writeRate),
                    color: .indigo
                )
            }
            MiniChart(
                samples: recent(monitor.histories.diskRead.samples),
                color: .cyan,
                secondarySamples: recent(monitor.histories.diskWrite.samples),
                secondaryColor: .indigo
            )
            .frame(height: 45)
        }
    }

    private var thermalCard: some View {
        OverviewMetricCard(title: "Thermal", symbol: "thermometer.medium", accent: thermalColor) {
            Text(monitor.metrics.thermal.rawValue)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(thermalColor)
            Text(thermalDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("Reported by macOS")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var uptimeCard: some View {
        OverviewMetricCard(title: "Uptime", symbol: "clock.arrow.circlepath", accent: .teal) {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text(MetricFormatter.uptime(ProcessInfo.processInfo.systemUptime))
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
            }
            Text("Since the last system restart")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var machineDescription: String {
        "\(monitor.machineInfo.name) · \(monitor.machineInfo.processor) · \(MetricFormatter.memory(monitor.machineInfo.physicalMemory))"
    }

    private var thermalColor: Color {
        switch monitor.metrics.thermal {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
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

    private func recent(_ samples: [Double]) -> [Double] {
        Array(samples.suffix(60))
    }
}
