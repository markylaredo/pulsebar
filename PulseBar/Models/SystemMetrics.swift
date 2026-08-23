import Foundation

struct CPUStats: Sendable {
    var totalUsage = 0.0
    var coreUsage: [Double] = []
    var loadAverages: [Double] = []
    var logicalCoreCount = ProcessInfo.processInfo.processorCount
}

struct MemoryStats: Sendable {
    var physical: UInt64 = ProcessInfo.processInfo.physicalMemory
    var used: UInt64 = 0
    var available: UInt64 = 0
    var appMemory: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var usage: Double { physical > 0 ? Double(used) / Double(physical) : 0 }
}

struct NetworkStats: Sendable {
    var downloadRate = 0.0
    var uploadRate = 0.0
    var packetsReceivedRate = 0.0
    var packetsSentRate = 0.0
    var totalReceived: UInt64 = 0
    var totalTransmitted: UInt64 = 0
    var totalPacketsReceived: UInt64 = 0
    var totalPacketsSent: UInt64 = 0
}

struct DiskStats: Sendable {
    var readRate = 0.0
    var writeRate = 0.0
    var totalRead: UInt64 = 0
    var totalWritten: UInt64 = 0
}

struct StorageStats: Sendable {
    var total: UInt64 = 0
    var available: UInt64 = 0
    var used: UInt64 { total >= available ? total - available : 0 }
    var usage: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct BatteryStats: Sendable {
    var percentage: Double
    var isCharging: Bool
    var isConnectedToPower: Bool
    var timeRemainingMinutes: Int?
}

enum ThermalStats: String, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}

struct SystemMetrics: Sendable {
    var cpu = CPUStats()
    var memory = MemoryStats()
    var network = NetworkStats()
    var disk = DiskStats()
    var storage = StorageStats()
    var battery: BatteryStats?
    var thermal = ThermalStats.nominal
}

struct MachineInfo: Sendable {
    var name = "Mac"
    var processor = "Unknown processor"
    var physicalMemory: UInt64 = 0
}

struct MetricHistories: Sendable {
    var cpu = MetricHistory()
    var memory = MetricHistory()
    var download = MetricHistory()
    var upload = MetricHistory()
    var packetsReceived = MetricHistory()
    var packetsSent = MetricHistory()
    var diskRead = MetricHistory()
    var diskWrite = MetricHistory()
}
