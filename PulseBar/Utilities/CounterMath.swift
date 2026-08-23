import Foundation

struct CPUTicks: Equatable, Sendable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var total: UInt64 { user &+ system &+ idle &+ nice }
    var busy: UInt64 { user &+ system &+ nice }
}

enum CounterMath {
    static func cpuUsage(previous: CPUTicks, current: CPUTicks) -> Double? {
        guard current.total >= previous.total, current.busy >= previous.busy else { return nil }
        let totalDelta = current.total - previous.total
        guard totalDelta > 0 else { return nil }
        return min(max(Double(current.busy - previous.busy) / Double(totalDelta), 0), 1)
    }

    static func rate(previous: UInt64, current: UInt64, elapsed: TimeInterval) -> Double? {
        guard elapsed > 0, current >= previous else { return nil }
        return Double(current - previous) / elapsed
    }
}
