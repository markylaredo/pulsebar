import SwiftUI

struct PerformanceDetailView: View {
    @Environment(SystemMonitor.self) private var monitor
    let metric: PerformanceMetric

    var body: some View {
        ScrollView {
            Group {
                switch metric {
                case .cpu: cpuDetail
                case .memory: memoryDetail
                case .gpu: gpuDetail
                case .disk: diskDetail
                case .network: networkDetail
                }
            }
            .frame(maxWidth: 900, alignment: .topLeading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .defaultScrollAnchor(.top)
    }

    private var cpuDetail: some View {
        let cpu = monitor.metrics.cpu
        return detailLayout(
            title: "CPU",
            symbol: PerformanceMetric.cpu.symbol,
            current: MetricFormatter.percentage(cpu.totalUsage),
            subtitle: monitor.machineInfo.processor,
            color: .blue,
            samples: monitor.histories.cpu.samples,
            fixedMaximum: 1,
            peak: "History peak  \(MetricFormatter.percentage(monitor.histories.cpu.samples.max() ?? 0))"
        ) {
            statGrid {
                PerformanceStat(label: "User", value: MetricFormatter.percentage(cpu.userUsage))
                PerformanceStat(label: "System", value: MetricFormatter.percentage(cpu.systemUsage))
                PerformanceStat(label: "Idle", value: MetricFormatter.percentage(cpu.idleUsage))
                PerformanceStat(label: "Logical Processors", value: String(cpu.logicalCoreCount))
                PerformanceStat(label: "Load Average", value: loadAverage)
                PerformanceStat(label: "Thermal", value: monitor.metrics.thermal.rawValue, color: thermalColor)
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    PerformanceStat(
                        label: "Uptime",
                        value: MetricFormatter.uptime(ProcessInfo.processInfo.systemUptime)
                    )
                }
            }
        }
    }

    private var memoryDetail: some View {
        let memory = monitor.metrics.memory
        return detailLayout(
            title: "Memory",
            symbol: PerformanceMetric.memory.symbol,
            current: "\(MetricFormatter.memory(memory.used)) / \(MetricFormatter.memory(memory.physical))",
            subtitle: "\(MetricFormatter.percentage(memory.usage)) used",
            color: .purple,
            samples: monitor.histories.memory.samples,
            fixedMaximum: 1,
            peak: "History peak  \(MetricFormatter.percentage(monitor.histories.memory.samples.max() ?? 0))"
        ) {
            statGrid {
                PerformanceStat(label: "Used", value: MetricFormatter.memory(memory.used))
                PerformanceStat(label: "Available", value: MetricFormatter.memory(memory.available))
                PerformanceStat(label: "App Memory", value: MetricFormatter.memory(memory.appMemory))
                PerformanceStat(label: "Wired", value: MetricFormatter.memory(memory.wired))
                PerformanceStat(label: "Compressed", value: MetricFormatter.memory(memory.compressed))
                PerformanceStat(label: "Cached", value: MetricFormatter.memory(memory.cached))
                PerformanceStat(label: "Swap Used", value: MetricFormatter.memory(memory.swapUsed))
                PerformanceStat(
                    label: "Pressure",
                    value: monitor.metrics.memoryPressure.rawValue,
                    color: memoryPressureColor
                )
            }
        }
    }

    private var gpuDetail: some View {
        VStack(alignment: .leading, spacing: 22) {
            metricHeader(
                title: "GPU",
                symbol: PerformanceMetric.gpu.symbol,
                current: monitor.machineInfo.gpu ?? "GPU",
                subtitle: "Graphics hardware",
                color: .teal
            )

            Divider()

            ContentUnavailableView(
                "Live GPU monitoring unavailable",
                systemImage: "rectangle.3.group",
                description: Text(
                    "PulseBar does not use private frameworks or undocumented system output to estimate GPU utilization."
                )
            )
            .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private var diskDetail: some View {
        let disk = monitor.metrics.disk
        return throughputLayout(
            title: "Disk Activity",
            symbol: PerformanceMetric.disk.symbol,
            primaryLabel: "Read",
            primaryValue: disk.readRate,
            primaryColor: .cyan,
            secondaryLabel: "Write",
            secondaryValue: disk.writeRate,
            secondaryColor: .indigo,
            primarySamples: monitor.histories.diskRead.samples,
            secondarySamples: monitor.histories.diskWrite.samples
        ) {
            statGrid {
                PerformanceStat(label: "Current Read", value: MetricFormatter.rate(disk.readRate), color: .cyan)
                PerformanceStat(label: "Current Write", value: MetricFormatter.rate(disk.writeRate), color: .indigo)
                PerformanceStat(label: "History Peak Read", value: MetricFormatter.rate(monitor.histories.diskRead.samples.max() ?? 0))
                PerformanceStat(label: "History Peak Write", value: MetricFormatter.rate(monitor.histories.diskWrite.samples.max() ?? 0))
            }
        }
    }

    private var networkDetail: some View {
        let network = monitor.metrics.network
        return throughputLayout(
            title: "Network",
            symbol: PerformanceMetric.network.symbol,
            primaryLabel: "Download",
            primaryValue: network.downloadRate,
            primaryColor: .green,
            secondaryLabel: "Upload",
            secondaryValue: network.uploadRate,
            secondaryColor: .orange,
            primarySamples: monitor.histories.download.samples,
            secondarySamples: monitor.histories.upload.samples
        ) {
            statGrid {
                PerformanceStat(label: "Current Download", value: MetricFormatter.rate(network.downloadRate), color: .green)
                PerformanceStat(label: "Current Upload", value: MetricFormatter.rate(network.uploadRate), color: .orange)
                PerformanceStat(label: "History Peak Download", value: MetricFormatter.rate(monitor.histories.download.samples.max() ?? 0))
                PerformanceStat(label: "History Peak Upload", value: MetricFormatter.rate(monitor.histories.upload.samples.max() ?? 0))
                PerformanceStat(label: "Packets In", value: MetricFormatter.packetRate(network.packetsReceivedRate))
                PerformanceStat(label: "Packets Out", value: MetricFormatter.packetRate(network.packetsSentRate))
                PerformanceStat(label: "Data Received", value: MetricFormatter.bytes(network.totalReceived))
                PerformanceStat(label: "Data Sent", value: MetricFormatter.bytes(network.totalTransmitted))
            }
        }
    }

    private func detailLayout<Stats: View>(
        title: String,
        symbol: String,
        current: String,
        subtitle: String,
        color: Color,
        samples: [Double],
        fixedMaximum: Double,
        peak: String,
        @ViewBuilder stats: () -> Stats
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            metricHeader(title: title, symbol: symbol, current: current, subtitle: subtitle, color: color)
            PerformanceChart(samples: samples, color: color, fixedMaximum: fixedMaximum)
                .frame(height: 250)
            chartFooter(sampleCount: samples.count, trailing: peak)
            Divider()
            stats()
        }
    }

    private func throughputLayout<Stats: View>(
        title: String,
        symbol: String,
        primaryLabel: String,
        primaryValue: Double,
        primaryColor: Color,
        secondaryLabel: String,
        secondaryValue: Double,
        secondaryColor: Color,
        primarySamples: [Double],
        secondarySamples: [Double],
        @ViewBuilder stats: () -> Stats
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 36) {
                Label(title, systemImage: symbol)
                    .font(.title2.weight(.semibold))
                Spacer()
                LiveDirectionValue(label: primaryLabel, value: primaryValue, color: primaryColor)
                LiveDirectionValue(label: secondaryLabel, value: secondaryValue, color: secondaryColor)
            }
            PerformanceChart(
                samples: primarySamples,
                color: primaryColor,
                secondarySamples: secondarySamples,
                secondaryColor: secondaryColor
            )
            .frame(height: 250)
            chartFooter(
                sampleCount: max(primarySamples.count, secondarySamples.count),
                trailing: "Auto-scaled to recent activity"
            )
            Divider()
            stats()
        }
    }

    private func metricHeader(
        title: String,
        symbol: String,
        current: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(current)
                    .font(.system(size: 36, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func chartFooter(sampleCount: Int, trailing: String) -> some View {
        HStack {
            Text("Live history · \(sampleCount) of 180 samples")
            Spacer()
            Text(trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private func statGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 155), spacing: 18, alignment: .leading)],
            alignment: .leading,
            spacing: 18,
            content: content
        )
    }

    private var loadAverage: String {
        let values = monitor.metrics.cpu.loadAverages
        guard !values.isEmpty else { return "Unavailable" }
        return values.map { String(format: "%.2f", $0) }.joined(separator: "  ")
    }

    private var thermalColor: Color {
        switch monitor.metrics.thermal {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }

    private var memoryPressureColor: Color {
        switch monitor.metrics.memoryPressure {
        case .normal: .green
        case .elevated: .orange
        case .critical: .red
        }
    }
}

private struct PerformanceStat: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LiveDirectionValue: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MetricFormatter.rate(value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
