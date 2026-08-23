import Charts
import SwiftUI

struct MiniChart: View {
    let samples: [Double]
    let color: Color
    let secondarySamples: [Double]
    let secondaryColor: Color?

    init(
        samples: [Double],
        color: Color,
        secondarySamples: [Double] = [],
        secondaryColor: Color? = nil
    ) {
        self.samples = samples
        self.color = color
        self.secondarySamples = secondarySamples
        self.secondaryColor = secondaryColor
    }

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("Sample", index), y: .value("Value", value))
                    .foregroundStyle(color.opacity(0.12))
                LineMark(
                    x: .value("Sample", index),
                    y: .value("Value", value),
                    series: .value("Direction", "Download")
                )
                .foregroundStyle(color)
                .lineStyle(.init(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            if let secondaryColor {
                ForEach(Array(secondarySamples.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("Value", value),
                        series: .value("Direction", "Upload")
                    )
                    .foregroundStyle(secondaryColor)
                    .lineStyle(.init(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }
}
