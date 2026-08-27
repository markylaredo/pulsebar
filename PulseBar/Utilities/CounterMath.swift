import Foundation

struct CPUTicks: Equatable, Sendable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var total: UInt64 { user &+ system &+ idle &+ nice }
    var busy: UInt64 { user &+ system &+ nice }
}

struct CPUBreakdown: Equatable, Sendable {
    let user: Double
    let system: Double
    let idle: Double

    var totalUsage: Double { min(max(user + system, 0), 1) }
}

enum CounterMath {
    static func cpuUsage(previous: CPUTicks, current: CPUTicks) -> Double? {
        cpuBreakdown(previous: previous, current: current)?.totalUsage
    }

    static func cpuBreakdown(previous: CPUTicks, current: CPUTicks) -> CPUBreakdown? {
        guard current.user >= previous.user,
              current.system >= previous.system,
              current.idle >= previous.idle,
              current.nice >= previous.nice,
              current.total >= previous.total else { return nil }
        let totalDelta = current.total - previous.total
        guard totalDelta > 0 else { return nil }
        let divisor = Double(totalDelta)
        return CPUBreakdown(
            user: Double(current.user - previous.user + current.nice - previous.nice) / divisor,
            system: Double(current.system - previous.system) / divisor,
            idle: Double(current.idle - previous.idle) / divisor
        )
    }

    static func rate(previous: UInt64, current: UInt64, elapsed: TimeInterval) -> Double? {
        guard elapsed > 0, current >= previous else { return nil }
        return Double(current - previous) / elapsed
    }
}
