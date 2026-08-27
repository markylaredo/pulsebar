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
        icon(
            for: process.id,
            processID: process.pid,
            executablePath: process.executablePath
        )
    }

    func icon(
        for identity: ProcessIdentity,
        processID: pid_t,
        executablePath: String?
    ) -> NSImage {
        if let cached = icons[identity] {
            return cached
        }

        let resolved = NSRunningApplication(processIdentifier: processID)?.icon
            ?? executablePath.map { NSWorkspace.shared.icon(forFile: $0) }
            ?? fallback
        icons[identity] = resolved
        return resolved
    }

    func prune(activeIdentities: Set<ProcessIdentity>) {
        icons = icons.filter { activeIdentities.contains($0.key) }
    }
}
