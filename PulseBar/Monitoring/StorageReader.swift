import Foundation

struct StorageReader {
    func read() -> StorageStats {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) else { return StorageStats() }
        return StorageStats(total: UInt64(max(0, values.volumeTotalCapacity ?? 0)), available: UInt64(max(0, values.volumeAvailableCapacityForImportantUsage ?? 0)))
    }
}
