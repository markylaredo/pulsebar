import Foundation
import Observation

@MainActor
@Observable
final class NetworkViewModel {
    private(set) var connections: [NetworkConnectionSnapshot] = []
    private(set) var interfaces: [NetworkInterfaceSnapshot] = []
    private(set) var isLoading = true
    private(set) var lastUpdated: Date?

    private let provider = NetworkInspectorProvider()

    func run() async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: .seconds(2.5))
            } catch {
                return
            }
        }
    }

    func refresh() async {
        let snapshot = await provider.snapshot()
        guard !Task.isCancelled else { return }
        if connections != snapshot.connections { connections = snapshot.connections }
        if interfaces != snapshot.interfaces { interfaces = snapshot.interfaces }
        isLoading = false
        lastUpdated = .now
        ProcessIconCache.shared.prune(activeIdentities: Set(connections.map(\.processIdentity)))
    }
}
