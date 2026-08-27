import SwiftUI

struct StorageView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage(SettingsKey.monitorDisk) private var diskMonitoringEnabled = true
    @State private var selection: VolumeSnapshot.ID?
    @State private var choseInitialSelection = false
    @State private var sortOrder = [KeyPathComparator(\VolumeSnapshot.sortName)]

    var body: some View {
        VStack(spacing: 0) {
            summary
            Divider()
            HSplitView {
                volumeTable
                    .frame(minWidth: 430)
                VolumeDetailView(volume: selectedVolume)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Storage")
        .onChange(of: monitor.volumes.map(\.id), initial: true) { _, identities in
            if !choseInitialSelection {
                selection = primaryVolume?.id
                choseInitialSelection = true
            } else if let selection, !identities.contains(selection) {
                self.selection = nil
            }
        }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 20) {
            primaryStorageSummary
                .frame(minWidth: 270, idealWidth: 310, maxWidth: 350)
            Divider()
            diskActivitySummary
                .frame(minWidth: 330, maxWidth: .infinity)
        }
        .padding(20)
        .frame(height: 216)
    }

    private var primaryStorageSummary: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(primaryVolume?.name ?? "Startup Disk", systemImage: "internaldrive.fill")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(format(primaryVolume?.usedCapacity))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("used of \(format(primaryVolume?.totalCapacity))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: primaryVolume?.usage ?? 0)
                .tint(capacityStatusColor)

            HStack(spacing: 18) {
                capacityValue("Used", primaryVolume?.usedCapacity)
                capacityValue("Available", primaryVolume?.availableCapacity)
                capacityValue("Total", primaryVolume?.totalCapacity)
            }

            Label(primaryStatus.rawValue, systemImage: capacityStatusSymbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(capacityStatusColor)
        }
    }

    private var diskActivitySummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Disk Activity")
                    .font(.headline)
                Spacer()
                if !diskMonitoringEnabled {
                    Label("Disabled in Settings", systemImage: "pause.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 20) {
                DirectionalMetricValue(
                    label: "Read",
                    symbol: "arrow.down",
                    value: MetricFormatter.rate(monitor.metrics.disk.readRate),
                    color: .cyan
                )
                DirectionalMetricValue(
                    label: "Write",
                    symbol: "arrow.up",
                    value: MetricFormatter.rate(monitor.metrics.disk.writeRate),
                    color: .indigo
                )
            }

            MiniChart(
                samples: recentReadSamples,
                color: .cyan,
                secondarySamples: recentWriteSamples,
                secondaryColor: .indigo
            )
            .frame(height: 58)

            HStack {
                Text("Peak read  \(MetricFormatter.rate(peakRead))")
                Spacer()
                Text("Peak write  \(MetricFormatter.rate(peakWrite))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var volumeTable: some View {
        ZStack {
            Table(sortedVolumes, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Volume", value: \.sortName) { volume in
                    HStack(spacing: 7) {
                        Image(systemName: symbol(for: volume.kind))
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(volume.name)
                                .lineLimit(1)
                            Text(volume.kind.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 145, ideal: 190)

                TableColumn("Capacity", value: \.capacitySortValue) { volume in
                    Text(format(volume.totalCapacity))
                        .monospacedDigit()
                }
                .width(min: 76, ideal: 88)

                TableColumn("Used", value: \.usedSortValue) { volume in
                    Text(format(volume.usedCapacity))
                        .monospacedDigit()
                }
                .width(min: 76, ideal: 88)

                TableColumn("Available", value: \.availableSortValue) { volume in
                    Text(format(volume.availableCapacity))
                        .monospacedDigit()
                }
                .width(min: 82, ideal: 94)

                TableColumn("Filesystem", value: \.filesystemSortValue) { volume in
                    Text(volume.filesystem ?? "Unavailable")
                        .lineLimit(1)
                }
                .width(min: 72, ideal: 90)
            }
            .alternatingRowBackgrounds(.enabled)

            if monitor.volumes.isEmpty {
                ContentUnavailableView(
                    "No mounted volumes",
                    systemImage: "internaldrive",
                    description: Text("Mounted storage will appear here automatically.")
                )
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Text(volumeCountDescription)
                Spacer()
                Text("Volumes update automatically")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.bar)
        }
    }

    private var sortedVolumes: [VolumeSnapshot] {
        monitor.volumes.sorted { lhs, rhs in
            for comparator in sortOrder {
                switch comparator.compare(lhs, rhs) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return lhs.id < rhs.id
        }
    }

    private var selectedVolume: VolumeSnapshot? {
        guard let selection else { return nil }
        return monitor.volumes.first { $0.id == selection }
    }

    private var primaryVolume: VolumeSnapshot? {
        monitor.volumes.first(where: \.isPrimary)
    }

    private var primaryStatus: StorageCapacityStatus {
        if let primaryVolume { return primaryVolume.capacityStatus }
        guard monitor.metrics.storage.total > 0 else { return .unavailable }
        return StorageCapacityStatus(usage: monitor.metrics.storage.usage)
    }

    private var capacityStatusColor: Color {
        switch primaryStatus {
        case .normal: .green
        case .gettingFull: .orange
        case .lowFreeSpace: .red
        case .unavailable: .secondary
        }
    }

    private var capacityStatusSymbol: String {
        switch primaryStatus {
        case .normal: "checkmark.circle"
        case .gettingFull: "exclamationmark.circle"
        case .lowFreeSpace: "exclamationmark.triangle"
        case .unavailable: "questionmark.circle"
        }
    }

    private var recentReadSamples: [Double] {
        Array(monitor.histories.diskRead.samples.suffix(60))
    }

    private var recentWriteSamples: [Double] {
        Array(monitor.histories.diskWrite.samples.suffix(60))
    }

    private var peakRead: Double { recentReadSamples.max() ?? 0 }
    private var peakWrite: Double { recentWriteSamples.max() ?? 0 }

    private var volumeCountDescription: String {
        "\(monitor.volumes.count) \(monitor.volumes.count == 1 ? "volume" : "volumes")"
    }

    private func capacityValue(_ label: String, _ value: UInt64?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(format(value))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func format(_ value: UInt64?) -> String {
        value.map(MetricFormatter.bytes) ?? "Unavailable"
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

private extension VolumeSnapshot {
    var filesystemSortValue: String { filesystem?.localizedLowercase ?? "" }
}
