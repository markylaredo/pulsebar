import SwiftUI

enum PerformanceMetric: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case gpu = "GPU"
    case disk = "Disk"
    case network = "Network"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .gpu: "rectangle.3.group"
        case .disk: "internaldrive"
        case .network: "network"
        }
    }

    var color: Color {
        switch self {
        case .cpu: .blue
        case .memory: .purple
        case .gpu: .teal
        case .disk: .cyan
        case .network: .green
        }
    }
}

struct PerformanceView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var selection = PerformanceMetric.cpu

    var body: some View {
        HSplitView {
            metricRail
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)
            PerformanceDetailView(metric: selection)
                .frame(minWidth: 500)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Performance")
    }

    private var metricRail: some View {
        List(selection: $selection) {
            ForEach(PerformanceMetric.allCases) { metric in
                metricRow(metric)
                    .tag(metric)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private func metricRow(_ metric: PerformanceMetric) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: metric.symbol)
                .foregroundStyle(metric.color)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.rawValue)
                    .font(.subheadline.weight(.medium))
                Text(primaryValue(for: metric))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(secondaryValue(for: metric))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private func primaryValue(for metric: PerformanceMetric) -> String {
        switch metric {
        case .cpu:
            MetricFormatter.percentage(monitor.metrics.cpu.totalUsage)
        case .memory:
            MetricFormatter.percentage(monitor.metrics.memory.usage)
        case .gpu:
            "Unavailable"
        case .disk:
            "↓ \(MetricFormatter.rate(monitor.metrics.disk.readRate))"
        case .network:
            "↓ \(MetricFormatter.rate(monitor.metrics.network.downloadRate))"
        }
    }

    private func secondaryValue(for metric: PerformanceMetric) -> String {
        switch metric {
        case .cpu:
            "\(monitor.metrics.cpu.logicalCoreCount) logical processors"
        case .memory:
            MetricFormatter.memory(monitor.metrics.memory.used)
        case .gpu:
            monitor.machineInfo.gpu ?? "Hardware unavailable"
        case .disk:
            "↑ \(MetricFormatter.rate(monitor.metrics.disk.writeRate))"
        case .network:
            "↑ \(MetricFormatter.rate(monitor.metrics.network.uploadRate))"
        }
    }
}
