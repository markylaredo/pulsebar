import Foundation
import IOKit

struct DiskReader {
    private var previous: (read: UInt64, written: UInt64, time: ContinuousClock.Instant)?

    mutating func read(now: ContinuousClock.Instant = .now) -> DiskStats {
        let totals = readTotals()
        defer { previous = (totals.read, totals.written, now) }
        guard let previous else { return DiskStats(totalRead: totals.read, totalWritten: totals.written) }
        let duration = previous.time.duration(to: now).components
        let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        return DiskStats(
            readRate: CounterMath.rate(previous: previous.read, current: totals.read, elapsed: elapsed) ?? 0,
            writeRate: CounterMath.rate(previous: previous.written, current: totals.written, elapsed: elapsed) ?? 0,
            totalRead: totals.read,
            totalWritten: totals.written
        )
    }

    mutating func reset() { previous = nil }

    private func readTotals() -> (read: UInt64, written: UInt64) {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOBlockStorageDriver"), IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iterator) }
        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let property = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else { continue }
            totalRead &+= (property["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            totalWritten &+= (property["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return (totalRead, totalWritten)
    }
}
