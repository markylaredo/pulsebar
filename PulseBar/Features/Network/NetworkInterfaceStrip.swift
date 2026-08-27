import SwiftUI

struct NetworkInterfaceStrip: View {
    let interfaces: [NetworkInterfaceSnapshot]

    var body: some View {
        HStack(spacing: 0) {
            primaryInterface
                .frame(width: 230, alignment: .leading)
                .padding(.horizontal, 14)

            Divider()

            if interfaces.isEmpty {
                Label("No interfaces available", systemImage: "network.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(interfaces) { interface in
                            interfaceItem(interface)
                            if interface.id != interfaces.last?.id {
                                Divider()
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(height: 82)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var primaryInterface: some View {
        let interface = interfaces.first(where: \.isPrimary)
            ?? interfaces.first(where: \.isActive)
        return VStack(alignment: .leading, spacing: 4) {
            Text("PRIMARY INTERFACE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if let interface {
                HStack(spacing: 6) {
                    Circle()
                        .fill(interface.isActive ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(interface.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(interface.name)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(interface.primaryAddress ?? "Address unavailable")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            } else {
                Text("Unavailable")
                    .font(.headline)
                Text("No active network interface")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func interfaceItem(_ interface: NetworkInterfaceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol(for: interface.kind))
                    .foregroundStyle(interface.isActive ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text(interface.name)
                    .font(.subheadline.weight(.semibold).monospaced())
                Text(interface.status)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(interface.isActive ? .green : .secondary)
            }
            Text(interface.kind.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(interface.primaryAddress ?? "No IP address")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .frame(width: 178, alignment: .leading)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
    }

    private func symbol(for kind: NetworkInterfaceKind) -> String {
        switch kind {
        case .wifi: "wifi"
        case .ethernet: "cable.connector"
        case .tunnel: "lock.shield"
        case .loopback: "arrow.trianglehead.2.clockwise.rotate.90"
        case .other: "network"
        }
    }
}
