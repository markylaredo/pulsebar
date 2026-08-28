import SwiftUI

struct ProcessListView: View {
    @Environment(SystemExplorerLifecycle.self) private var lifecycle
    @State private var model = ProcessViewModel()
    @State private var searchText = ""
    @State private var selection: ProcessIdentity?
    @State private var sortOrder = [
        KeyPathComparator(\ProcessSnapshot.cpuUsage, order: .reverse),
        KeyPathComparator(\ProcessSnapshot.sortName)
    ]

    var body: some View {
        HSplitView {
            tablePane
                .frame(minWidth: 470)
            ProcessDetailView(
                process: selectedProcess,
                actionMessage: model.actionMessage,
                onQuit: { process in
                    Task { await model.terminate(process, force: false) }
                },
                onForceQuit: { process in
                    Task { await model.terminate(process, force: true) }
                }
            )
            .frame(minWidth: 270, idealWidth: 320, maxWidth: 380)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search processes")
        .navigationTitle("Processes")
        .task(id: lifecycle.isVisible) {
            guard lifecycle.isVisible else { return }
            await model.run()
        }
        .onChange(of: model.processes.map(\.id)) { _, identities in
            if let selection, !identities.contains(selection) {
                self.selection = nil
            }
        }
        .onChange(of: searchText) { _, query in
            if let selection,
               !model.processes.contains(where: { $0.id == selection && $0.matches(query) }) {
                self.selection = nil
            }
        }
        .onChange(of: selection) { _, _ in
            model.clearActionMessage()
        }
    }

    private var tablePane: some View {
        ZStack {
            Table(displayedProcesses, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Process", value: \.sortName) { process in
                    HStack(spacing: 7) {
                        Image(nsImage: ProcessIconCache.shared.icon(for: process))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                        Text(process.name)
                            .lineLimit(1)
                    }
                }
                .width(min: 190, ideal: 260)

                TableColumn("PID", value: \.pid) { process in
                    Text(String(process.pid))
                        .monospacedDigit()
                }
                .width(min: 58, ideal: 68, max: 78)

                TableColumn("CPU", value: \.cpuUsage) { process in
                    Text(MetricFormatter.processPercentage(process.cpuUsage))
                        .monospacedDigit()
                }
                .width(min: 64, ideal: 74, max: 84)

                TableColumn("Memory", value: \.residentMemory) { process in
                    Text(MetricFormatter.memory(process.residentMemory))
                        .monospacedDigit()
                }
                .width(min: 82, ideal: 96, max: 112)
            }
            .alternatingRowBackgrounds(.enabled)

            if model.isLoading {
                ProgressView("Loading processes…")
                    .controlSize(.small)
            } else if displayedProcesses.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No processes available" : "No matching processes",
                    systemImage: searchText.isEmpty ? "list.bullet.rectangle" : "magnifyingglass",
                    description: Text(emptyDescription)
                )
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Text(processCountDescription)
                Spacer()
                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.orange)
                } else {
                    Text("Updates every 2 seconds")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.bar)
        }
    }

    private var displayedProcesses: [ProcessSnapshot] {
        let filtered = model.processes.filter { $0.matches(searchText) }
        return filtered.sorted { lhs, rhs in
            for comparator in sortOrder {
                switch comparator.compare(lhs, rhs) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            if lhs.sortName != rhs.sortName { return lhs.sortName < rhs.sortName }
            if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
            return lhs.id.startTimeMicroseconds < rhs.id.startTimeMicroseconds
        }
    }

    private var selectedProcess: ProcessSnapshot? {
        guard let selection else { return nil }
        return model.processes.first { $0.id == selection }
    }

    private var processCountDescription: String {
        if searchText.isEmpty {
            return "\(model.processes.count) processes"
        }
        return "\(displayedProcesses.count) of \(model.processes.count) processes"
    }

    private var emptyDescription: String {
        if searchText.isEmpty {
            return "PulseBar could not read the current process list."
        }
        return "No processes match \"\(searchText)\"."
    }
}
