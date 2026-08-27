import AppKit
import SwiftUI

struct SystemInfoSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.primary)
            Divider()
            content
        }
        .padding(.vertical, 4)
    }
}

struct SystemInfoRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .fontDesign(monospaced ? .monospaced : .default)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button("Copy \(label)", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    }
                }
        }
        .font(.subheadline)
    }
}
