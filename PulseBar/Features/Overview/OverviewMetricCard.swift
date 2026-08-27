import SwiftUI

struct OverviewMetricCard<Content: View>: View {
    let title: String
    let symbol: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
            }
            .font(.subheadline.weight(.semibold))

            content
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
        .accessibilityElement(children: .contain)
    }
}

struct DirectionalMetricValue: View {
    let label: String
    let symbol: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
