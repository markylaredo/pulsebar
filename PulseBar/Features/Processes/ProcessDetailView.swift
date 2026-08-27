import AppKit
import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessSnapshot?
    let actionMessage: String?
    let onQuit: (ProcessSnapshot) -> Void
    let onForceQuit: (ProcessSnapshot) -> Void

    @State private var pendingForceQuit: ProcessSnapshot?

    var body: some View {
        Group {
            if let process {
                details(for: process)
            } else {
                ContentUnavailableView(
                    "Select a process",
                    systemImage: "info.circle",
                    description: Text("Choose a row to inspect its current resource use and details.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34))
        .alert(
            "Force quit \(pendingForceQuit?.name ?? "process")?",
            isPresented: Binding(
                get: { pendingForceQuit != nil },
                set: { if !$0 { pendingForceQuit = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                pendingForceQuit = nil
            }
            Button("Force Quit", role: .destructive) {
                guard let process = pendingForceQuit else { return }
                pendingForceQuit = nil
                onForceQuit(process)
            }
        } message: {
            Text("Unsaved work in this process may be lost.")
        }
    }

    private func details(for process: ProcessSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(nsImage: ProcessIconCache.shared.icon(for: process))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(process.name)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                        Text("PID \(process.pid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    detailRow("CPU", MetricFormatter.processPercentage(process.cpuUsage))
                    detailRow("Memory", MetricFormatter.memory(process.residentMemory))
                    detailRow("Threads", String(process.threadCount))
                    detailRow("Architecture", process.architecture ?? "Unavailable")
                    detailRow("Running", MetricFormatter.uptime(Date().timeIntervalSince(process.launchDate)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Executable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(process.executablePath ?? "Unavailable")
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }

                Divider()

                HStack(spacing: 8) {
                    Button("Quit") { onQuit(process) }
                        .disabled(!process.canTerminate)
                    Button("Force Quit", role: .destructive) {
                        pendingForceQuit = process
                    }
                    .disabled(!process.canTerminate)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button("Reveal in Finder", systemImage: "folder") {
                        reveal(process)
                    }
                    .disabled(process.executablePath == nil)
                    Button("Copy PID", systemImage: "doc.on.doc") {
                        copy(String(process.pid))
                    }
                    Button("Copy Executable Path", systemImage: "doc.on.doc") {
                        if let path = process.executablePath { copy(path) }
                    }
                    .disabled(process.executablePath == nil)
                }
                .buttonStyle(.plain)

                if let actionMessage {
                    Label(actionMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !process.canTerminate {
                    Label(
                        "This system process cannot be terminated by PulseBar.",
                        systemImage: "lock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
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

    private func reveal(_ process: ProcessSnapshot) {
        guard let path = process.executablePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
