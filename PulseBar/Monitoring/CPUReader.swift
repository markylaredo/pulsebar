import Darwin
import Foundation

struct CPUReader {
    private var previousTicks: [CPUTicks]?

    mutating func read() -> CPUStats {
        guard let current = readTicks() else { return CPUStats() }
        defer { previousTicks = current }

        var stats = CPUStats()
        stats.logicalCoreCount = current.count
        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, Int32(loads.count)) > 0 { stats.loadAverages = loads }

        guard let previousTicks, previousTicks.count == current.count else { return stats }
        stats.coreUsage = zip(previousTicks, current).map { CounterMath.cpuUsage(previous: $0, current: $1) ?? 0 }
        let previousTotal = previousTicks.reduce(CPUTicks(user: 0, system: 0, idle: 0, nice: 0), +)
        let currentTotal = current.reduce(CPUTicks(user: 0, system: 0, idle: 0, nice: 0), +)
        stats.totalUsage = CounterMath.cpuUsage(previous: previousTotal, current: currentTotal) ?? 0
        return stats
    }

    mutating func reset() { previousTicks = nil }

    private func readTicks() -> [CPUTicks]? {
        var cpuInfo: processor_info_array_t?
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &infoCount)
        guard result == KERN_SUCCESS, let cpuInfo else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        return (0..<Int(cpuCount)).map { index in
            let offset = index * Int(CPU_STATE_MAX)
            return CPUTicks(
                user: UInt64(cpuInfo[offset + Int(CPU_STATE_USER)]),
                system: UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                idle: UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)]),
                nice: UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])
            )
        }
    }
}

private func + (lhs: CPUTicks, rhs: CPUTicks) -> CPUTicks {
    CPUTicks(user: lhs.user &+ rhs.user, system: lhs.system &+ rhs.system, idle: lhs.idle &+ rhs.idle, nice: lhs.nice &+ rhs.nice)
}
