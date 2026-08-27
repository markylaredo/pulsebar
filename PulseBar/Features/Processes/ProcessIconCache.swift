import AppKit

@MainActor
final class ProcessIconCache {
    static let shared = ProcessIconCache()

    private var icons: [ProcessIdentity: NSImage] = [:]
    private let fallback = NSImage(
        systemSymbolName: "terminal",
        accessibilityDescription: "Process"
    ) ?? NSImage()

    func icon(for process: ProcessSnapshot) -> NSImage {
        if let cached = icons[process.id] {
            return cached
        }

        let resolved = NSRunningApplication(processIdentifier: process.pid)?.icon
            ?? process.executablePath.map { NSWorkspace.shared.icon(forFile: $0) }
            ?? fallback
        icons[process.id] = resolved
        return resolved
    }

    func prune(activeIdentities: Set<ProcessIdentity>) {
        icons = icons.filter { activeIdentities.contains($0.key) }
    }
}
