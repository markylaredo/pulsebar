import Foundation

struct MenuBarPresentation {
    let text: String
    let accessibilityLabel: String
    let parts: [MenuBarMetricPart]
    let widthBehavior: MenuBarWidthBehavior

    var preferredWidth: CGFloat {
        guard !parts.isEmpty else { return 88 }
        let metricsWidth = parts.reduce(CGFloat.zero) { $0 + $1.reservedWidth }
        let separatorsWidth = CGFloat(max(0, parts.count - 1)) * 6
        return ceil(metricsWidth + separatorsWidth + 12)
    }

    static func make(metrics: SystemMetrics, defaults: UserDefaults = .standard) -> Self {
        let compact = defaults.bool(forKey: SettingsKey.compactMenuBar)
        let widthBehavior = MenuBarWidthBehavior(
            rawValue: defaults.string(forKey: SettingsKey.menuBarWidthBehavior) ?? ""
        ) ?? .fixed
        let parts = MenuBarMetric
            .ordered(from: defaults.string(forKey: SettingsKey.menuBarMetricOrder))
            .compactMap { part(for: $0, metrics: metrics, compact: compact, defaults: defaults) }

        let visibleParts = Array(parts.prefix(5))
        let text = visibleParts.isEmpty ? "PulseBar" : visibleParts.map(\.text).joined(separator: " · ")
        return Self(
            text: text,
            accessibilityLabel: "PulseBar, \(visibleParts.map(\.text).joined(separator: ", "))",
            parts: visibleParts,
            widthBehavior: widthBehavior
        )
    }

    private static func part(
        for metric: MenuBarMetric,
        metrics: SystemMetrics,
        compact: Bool,
        defaults: UserDefaults
    ) -> MenuBarMetricPart? {
        guard defaults.bool(forKey: metric.visibilityKey) else { return nil }
        switch metric {
        case .cpu:
            return .init(id: metric, prefix: compact ? "" : "CPU ", value: MetricFormatter.percentage(metrics.cpu.totalUsage), numericValue: metrics.cpu.totalUsage * 100)
        case .memory:
            return .init(id: metric, prefix: compact ? "" : "RAM ", value: MetricFormatter.percentage(metrics.memory.usage), numericValue: metrics.memory.usage * 100)
        case .download:
            return .init(id: metric, prefix: "↓", value: MetricFormatter.compactRate(metrics.network.downloadRate), numericValue: metrics.network.downloadRate)
        case .upload:
            return .init(id: metric, prefix: "↑", value: MetricFormatter.compactRate(metrics.network.uploadRate), numericValue: metrics.network.uploadRate)
        case .diskRead:
            return .init(id: metric, prefix: "R ", value: MetricFormatter.compactRate(metrics.disk.readRate), numericValue: metrics.disk.readRate)
        case .diskWrite:
            return .init(id: metric, prefix: "W ", value: MetricFormatter.compactRate(metrics.disk.writeRate), numericValue: metrics.disk.writeRate)
        case .battery:
            guard let battery = metrics.battery else { return nil }
            return .init(id: metric, prefix: "🔋", value: MetricFormatter.percentage(battery.percentage), numericValue: battery.percentage * 100)
        }
    }
}

struct MenuBarMetricPart: Identifiable {
    let id: MenuBarMetric
    let prefix: String
    let value: String
    let numericValue: Double

    var text: String { prefix + value }

    var symbolName: String? {
        switch id {
        case .cpu: "waveform.path.ecg"
        case .memory where prefix.isEmpty: "memorychip"
        default: nil
        }
    }

    var reservedWidth: CGFloat {
        switch id {
        case .cpu: prefix.isEmpty ? 50 : 82
        case .memory: prefix.isEmpty ? 50 : 64
        case .download, .upload: 56
        case .diskRead, .diskWrite: 62
        case .battery: 54
        }
    }
}
