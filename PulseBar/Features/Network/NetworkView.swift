import SwiftUI

struct NetworkView: View {
    @Environment(SystemExplorerLifecycle.self) private var lifecycle
    @State private var model = NetworkViewModel()
    @State private var searchText = ""
    @State private var filter = NetworkConnectionFilter.all
    @State private var selection: NetworkConnectionID?
    @State private var sortOrder = [
        KeyPathComparator(\NetworkConnectionSnapshot.sortName),
        KeyPathComparator(\NetworkConnectionSnapshot.pid),
        KeyPathComparator(\NetworkConnectionSnapshot.localPort)
    ]

    var body: some View {
        VStack(spacing: 0) {
            NetworkActivitySummary(
                connectionCount: model.connections.count,
                listeningCount: listeningCount
            )
            Divider()
            NetworkInterfaceStrip(interfaces: model.interfaces)
            Divider()
            filterBar
            Divider()
            connectionTable
            if let selectedConnection {
                Divider()
                NetworkConnectionDetailView(connection: selectedConnection) {
                    selection = nil
                }
            }
        }
        .navigationTitle("Network")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search connections")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh connections", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }
        }
        .task(id: lifecycle.isVisible) {
            guard lifecycle.isVisible else { return }
            await model.run()
        }
        .onChange(of: model.connections.map(\.id)) { _, _ in reconcileSelection() }
        .onChange(of: searchText) { _, _ in reconcileSelection() }
        .onChange(of: filter) { _, _ in reconcileSelection() }
        .transaction { $0.animation = nil }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Connection filter", selection: $filter) {
                ForEach(NetworkConnectionFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 430)

            Spacer()

            Text(resultDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.bar)
    }

    private var connectionTable: some View {
        ZStack {
            Table(displayedConnections, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Process", value: \.sortName) { connection in
                    HStack(spacing: 7) {
                        Image(nsImage: ProcessIconCache.shared.icon(
                            for: connection.processIdentity,
                            processID: connection.pid,
                            executablePath: connection.executablePath
                        ))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                        Text(connection.processName)
                            .lineLimit(1)
                    }
                }
                .width(min: 140, ideal: 190)

                TableColumn("PID", value: \.pid) { connection in
                    Text(String(connection.pid))
                        .monospacedDigit()
                }
                .width(min: 52, ideal: 60, max: 70)

                TableColumn("Proto", value: \.protocolName) { connection in
                    Text(connection.protocolName)
                        .font(.caption.monospaced())
                        .foregroundStyle(connection.transport == .tcp ? Color.blue : Color.purple)
                }
                .width(min: 50, ideal: 58, max: 66)

                TableColumn("Local", value: \.localPort) { connection in
                    Text(connection.localDisplayName)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .width(min: 145, ideal: 190)

                TableColumn("Remote", value: \.remotePort) { connection in
                    Text(connection.remoteDisplayName)
                        .font(.body.monospaced())
                        .foregroundStyle(connection.remote == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .width(min: 145, ideal: 190)

                TableColumn("State", value: \.stateName) { connection in
                    Text(connection.stateName)
                        .font(.caption)
                        .foregroundStyle(stateColor(connection))
                        .lineLimit(1)
                }
                .width(min: 78, ideal: 92, max: 110)
            }
            .alternatingRowBackgrounds(.enabled)

            if model.isLoading {
                ProgressView("Inspecting network connections…")
                    .controlSize(.small)
            } else if displayedConnections.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: searchText.isEmpty ? "network.slash" : "magnifyingglass",
                    description: Text(emptyDescription)
                )
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    private var displayedConnections: [NetworkConnectionSnapshot] {
        model.connections
            .filter { filter.includes($0) && $0.matches(searchText) }
            .sorted { lhs, rhs in
                for comparator in sortOrder {
                    switch comparator.compare(lhs, rhs) {
                    case .orderedAscending: return true
                    case .orderedDescending: return false
                    case .orderedSame: continue
                    }
                }
                if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
                if lhs.id.socketHandle != rhs.id.socketHandle {
                    return lhs.id.socketHandle < rhs.id.socketHandle
                }
                return lhs.localDisplayName < rhs.localDisplayName
            }
    }

    private var selectedConnection: NetworkConnectionSnapshot? {
        guard let selection else { return nil }
        return model.connections.first { $0.id == selection }
    }

    private var listeningCount: Int {
        Set(model.connections.lazy.filter(\.isListening).map {
            "\($0.protocolName)|\($0.local.address)|\($0.local.port)"
        }).count
    }

    private var resultDescription: String {
        let total = model.connections.count
        return displayedConnections.count == total
            ? "\(total) sockets · refreshes every 2.5s"
            : "\(displayedConnections.count) of \(total) sockets"
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "No matching connections" }
        return filter == .all ? "No connections available" : "No \(filter.rawValue.lowercased()) connections"
    }

    private var emptyDescription: String {
        if !searchText.isEmpty { return "No connection matches \"\(searchText)\"." }
        if filter == .all {
            return "macOS may restrict socket details for some processes. Available connections will appear automatically."
        }
        return "Change the filter to see other active sockets."
    }

    private func reconcileSelection() {
        guard let selection,
              !displayedConnections.contains(where: { $0.id == selection }) else { return }
        self.selection = nil
    }

    private func stateColor(_ connection: NetworkConnectionSnapshot) -> Color {
        switch connection.state {
        case .established: .green
        case .listen: .purple
        case .closeWait, .closing, .lastAck: .orange
        case .none: .secondary
        default: .secondary
        }
    }
}

private struct NetworkActivitySummary: View {
    @Environment(SystemMonitor.self) private var monitor
    let connectionCount: Int
    let listeningCount: Int

    var body: some View {
        HStack(spacing: 0) {
            SummaryValue(
                label: "Download",
                value: MetricFormatter.rate(monitor.metrics.network.downloadRate),
                symbol: "arrow.down",
                color: .green
            )
            SummaryValue(
                label: "Upload",
                value: MetricFormatter.rate(monitor.metrics.network.uploadRate),
                symbol: "arrow.up",
                color: .orange
            )
            SummaryValue(
                label: "Active Connections",
                value: MetricFormatter.count(UInt64(connectionCount)),
                symbol: "point.3.connected.trianglepath.dotted",
                color: .blue
            )
            SummaryValue(
                label: "Listening Ports",
                value: MetricFormatter.count(UInt64(listeningCount)),
                symbol: "dot.radiowaves.left.and.right",
                color: .purple
            )
        }
        .frame(height: 72)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SummaryValue: View {
    let label: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 8)
            Divider()
                .padding(.vertical, 8)
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
