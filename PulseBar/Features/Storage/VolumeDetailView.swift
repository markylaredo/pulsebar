import AppKit
import SwiftUI

struct VolumeDetailView: View {
    let volume: VolumeSnapshot?

    var body: some View {
        Group {
            if let volume {
                details(for: volume)
            } else {
                ContentUnavailableView(
                    "Select a volume",
                    systemImage: "info.circle",
                    description: Text("Choose a row to inspect its capacity and mount information.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34))
    }

    private func details(for volume: VolumeSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: symbol(for: volume.kind))
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.name)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                        Text(volume.kind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    detailRow("Filesystem", volume.filesystem ?? "Unavailable")
                    detailRow("Capacity", format(volume.totalCapacity))
                    detailRow("Used", format(volume.usedCapacity))
                    detailRow("Available", format(volume.availableCapacity))
                    detailRow("Usage", volume.usage.map(MetricFormatter.percentage) ?? "Unavailable")
                    detailRow("Read Only", yesNo(volume.isReadOnly))
                    detailRow("Location", volume.isLocal.map { $0 ? "Local" : "Network" } ?? "Unavailable")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mount Point")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(volume.mountPath)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Button("Reveal in Finder", systemImage: "folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: volume.mountPath, isDirectory: true))
                    }
                    Button("Copy Mount Path", systemImage: "doc.on.doc") {
                        copy(volume.mountPath)
                    }
                    Button("Copy Volume Name", systemImage: "doc.on.doc") {
                        copy(volume.name)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private func format(_ value: UInt64?) -> String {
        value.map(MetricFormatter.bytes) ?? "Unavailable"
    }

    private func yesNo(_ value: Bool?) -> String {
        value.map { $0 ? "Yes" : "No" } ?? "Unavailable"
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func symbol(for kind: VolumeKind) -> String {
        switch kind {
        case .internalDrive: "internaldrive"
        case .externalDrive, .removable: "externaldrive"
        case .network: "network"
        case .unknown: "questionmark.square.dashed"
        }
    }
}
