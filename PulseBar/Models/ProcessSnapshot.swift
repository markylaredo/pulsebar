import Foundation

struct ProcessIdentity: Hashable, Sendable {
    let pid: pid_t
    let startTimeMicroseconds: UInt64
}

struct ProcessSnapshot: Identifiable, Sendable {
    let id: ProcessIdentity
    let name: String
    let cpuUsage: Double
    let residentMemory: UInt64
    let threadCount: Int
    let architecture: String?
    let executablePath: String?
    let launchDate: Date
    let canTerminate: Bool

    var pid: pid_t { id.pid }
    var sortName: String { name.localizedLowercase }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(normalizedQuery)
            || String(pid).contains(normalizedQuery)
    }
}

struct ProcessCPUSample: Sendable {
    let totalTimeNanoseconds: UInt64
    let timestampNanoseconds: UInt64
}

enum ProcessCPUCalculator {
    static func percentage(previous: ProcessCPUSample?, current: ProcessCPUSample) -> Double {
        guard let previous,
              current.totalTimeNanoseconds >= previous.totalTimeNanoseconds,
              current.timestampNanoseconds > previous.timestampNanoseconds else {
            return 0
        }

        let used = current.totalTimeNanoseconds - previous.totalTimeNanoseconds
        let elapsed = current.timestampNanoseconds - previous.timestampNanoseconds
        return min(max(Double(used) / Double(elapsed) * 100, 0), 9_999)
    }
}

enum ProcessActionResult: Sendable, Equatable {
    case success
    case failure(String)
}
