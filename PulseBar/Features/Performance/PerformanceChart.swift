import Charts
import SwiftUI

struct PerformanceChart: View {
    let samples: [Double]
    let color: Color
    let secondarySamples: [Double]
    let secondaryColor: Color?
    let fixedMaximum: Double?
    let accessibilityLabel: String
    let accessibilityValue: String

    init(
        samples: [Double],
        color: Color,
        secondarySamples: [Double] = [],
        secondaryColor: Color? = nil,
        fixedMaximum: Double? = nil,
        accessibilityLabel: String = "Performance history",
        accessibilityValue: String = "No samples"
    ) {
        self.samples = samples
        self.color = color
        self.secondarySamples = secondarySamples
        self.secondaryColor = secondaryColor
        self.fixedMaximum = fixedMaximum
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(.quaternary)

            ForEach(Array(samples.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Sample", index),
                    y: .value("Value", value),
                    series: .value("Series", "Primary")
                )
                .foregroundStyle(color.opacity(0.12))
                LineMark(
                    x: .value("Sample", index),
                    y: .value("Value", value),
                    series: .value("Series", "Primary")
                )
                .foregroundStyle(color)
                .lineStyle(.init(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }

            if let secondaryColor {
                ForEach(Array(secondarySamples.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("Value", value),
                        series: .value("Series", "Secondary")
                    )
                    .foregroundStyle(secondaryColor)
                    .lineStyle(.init(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .chartXScale(domain: 0...max(1, max(samples.count, secondarySamples.count) - 1))
        .chartYScale(domain: 0...resolvedMaximum)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var resolvedMaximum: Double {
        if let fixedMaximum { return max(fixedMaximum, 1) }
        let maximum = max(samples.max() ?? 0, secondarySamples.max() ?? 0)
        return max(1, maximum * 1.08)
    }
}
