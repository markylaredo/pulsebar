import Foundation
import Observation

@MainActor
@Observable
final class ProcessViewModel {
    private(set) var processes: [ProcessSnapshot] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private(set) var actionMessage: String?

    private let monitor = ProcessMonitor()

    func run() async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
        }
    }

    func terminate(_ process: ProcessSnapshot, force: Bool) async {
        actionMessage = nil
        let result = await monitor.terminate(process.id, force: force)
        switch result {
        case .success:
            await refresh()
        case .failure(let message):
            actionMessage = message
        }
    }

    func clearActionMessage() {
        actionMessage = nil
    }

    private func refresh() async {
        let snapshots = await monitor.sample()
        guard !Task.isCancelled else { return }
        processes = snapshots
        isLoading = false
        errorMessage = snapshots.isEmpty ? "Process information is unavailable." : nil
        ProcessIconCache.shared.prune(activeIdentities: Set(snapshots.map(\.id)))
    }
}
