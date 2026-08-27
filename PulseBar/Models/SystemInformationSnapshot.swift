import Foundation

struct HardwareInformation: Equatable, Sendable {
    let modelName: String
    let modelIdentifier: String
    let chip: String
    let architecture: String
    let physicalMemory: UInt64
    let logicalProcessorCount: Int
}

struct OperatingSystemInformation: Equatable, Sendable {
    let version: String
    let build: String
    let kernel: String
    let computerName: String
    let hostname: String
    let bootDate: Date
}

struct SystemInformationSnapshot: Equatable, Sendable {
    let hardware: HardwareInformation
    let operatingSystem: OperatingSystemInformation
}

struct DisplaySnapshot: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
    let pixelWidth: Int
    let pixelHeight: Int
    let scaledWidth: Int
    let scaledHeight: Int
    let refreshRate: Int?
    let isMain: Bool
    let isBuiltIn: Bool
    let isRetina: Bool
}

enum ShareSafeIPAddress {
    static func contains(_ address: String) -> Bool {
        let value = address.split(separator: "%", maxSplits: 1).first.map(String.init) ?? address
        if value.contains(":"), let first = ipv6FirstByte(value) {
            return value == "::1" || first & 0xFE == 0xFC || (first == 0xFE && ipv6SecondByte(value) & 0xC0 == 0x80)
        }

        let octets = value.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        return octets[0] == 10
            || octets[0] == 127
            || (octets[0] == 100 && (64...127).contains(octets[1]))
            || (octets[0] == 169 && octets[1] == 254)
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }

    private static func ipv6FirstByte(_ address: String) -> UInt8? {
        guard let group = address.split(separator: ":", omittingEmptySubsequences: true).first,
              let value = UInt16(group, radix: 16) else { return nil }
        return UInt8(value >> 8)
    }

    private static func ipv6SecondByte(_ address: String) -> UInt8 {
        guard let group = address.split(separator: ":", omittingEmptySubsequences: true).first,
              let value = UInt16(group, radix: 16) else { return 0 }
        return UInt8(value & 0xFF)
    }
}

enum SystemReportFormatter {
    static func report(
        system: SystemInformationSnapshot,
        displays: [DisplaySnapshot],
        battery: BatteryStats?,
        volumes: [VolumeSnapshot],
        interfaces: [NetworkInterfaceSnapshot],
        uptime: TimeInterval
    ) -> String {
        var sections = [
            "PulseBar System Report",
            "" ,
            "Mac",
            system.hardware.modelName,
            "Model: \(system.hardware.modelIdentifier)",
            "Chip: \(system.hardware.chip)",
            "Architecture: \(system.hardware.architecture)",
            "Memory: \(MetricFormatter.memory(system.hardware.physicalMemory))",
            "Logical CPUs: \(system.hardware.logicalProcessorCount)",
            "",
            "Operating System",
            "macOS \(system.operatingSystem.version)",
            "Build: \(system.operatingSystem.build)",
            "Kernel: \(system.operatingSystem.kernel)",
            "Uptime: \(MetricFormatter.uptime(uptime))"
        ]

        if !displays.isEmpty {
            sections.append(contentsOf: ["", "Displays"])
            for display in displays {
                sections.append(display.name)
                sections.append("Resolution: \(display.pixelWidth) × \(display.pixelHeight)\(refreshSuffix(display.refreshRate))")
            }
        }

        if let battery {
            sections.append(contentsOf: [
                "", "Battery",
                "Charge: \(MetricFormatter.percentage(battery.percentage))",
                "Status: \(battery.isCharging ? "Charging" : battery.isConnectedToPower ? "Connected to Power" : "On Battery")"
            ])
            if let cycleCount = battery.cycleCount { sections.append("Cycle Count: \(cycleCount)") }
            if let condition = battery.condition { sections.append("Condition: \(condition)") }
        }

        let visibleVolumes = volumes.filter { $0.totalCapacity != nil }
        if !visibleVolumes.isEmpty {
            sections.append(contentsOf: ["", "Storage"])
            for volume in visibleVolumes {
                sections.append(volume.name)
                if let total = volume.totalCapacity { sections.append("Total: \(MetricFormatter.bytes(total))") }
                if let used = volume.usedCapacity { sections.append("Used: \(MetricFormatter.bytes(used))") }
                if let available = volume.availableCapacity { sections.append("Available: \(MetricFormatter.bytes(available))") }
            }
        }

        let visibleInterfaces = interfaces.filter(\.isSystemRelevant)
        if !visibleInterfaces.isEmpty {
            sections.append(contentsOf: ["", "Network"])
            for interface in visibleInterfaces {
                sections.append("\(interface.kind.rawValue) (\(interface.name)) — \(interface.status)")
                if let address = (interface.ipv4Addresses + interface.ipv6Addresses).first(where: ShareSafeIPAddress.contains) {
                    sections.append("Address: \(address)")
                }
            }
        }

        return sections.joined(separator: "\n")
    }

    private static func refreshSuffix(_ refreshRate: Int?) -> String {
        refreshRate.map { " @ \($0) Hz" } ?? ""
    }
}
