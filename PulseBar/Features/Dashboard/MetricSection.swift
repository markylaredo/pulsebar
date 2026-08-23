import SwiftUI

struct MetricSection<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.headline).monospacedDigit()
            }
            content
        }
        .accessibilityElement(children: .contain)
    }
}
