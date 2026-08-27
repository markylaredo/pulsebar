import AppKit
import CoreGraphics
import Darwin
import Foundation

actor SystemInformationReader {
    func read() -> SystemInformationSnapshot {
        let processInfo = ProcessInfo.processInfo
        let computerName = Host.current().localizedName ?? "Mac"
        let modelIdentifier = sysctlString("hw.model") ?? "Unavailable"
        let version = processInfo.operatingSystemVersion

        return SystemInformationSnapshot(
            hardware: HardwareInformation(
                modelName: modelName(computerName: computerName, identifier: modelIdentifier),
                modelIdentifier: modelIdentifier,
                chip: sysctlString("machdep.cpu.brand_string") ?? "Unavailable",
                architecture: architecture,
                physicalMemory: processInfo.physicalMemory,
                logicalProcessorCount: processInfo.processorCount
            ),
            operatingSystem: OperatingSystemInformation(
                version: operatingSystemVersion(version),
                build: sysctlString("kern.osversion") ?? "Unavailable",
                kernel: sysctlString("kern.osrelease").map { "Darwin \($0)" } ?? "Unavailable",
                computerName: computerName,
                hostname: processInfo.hostName,
                bootDate: Date(timeIntervalSinceNow: -processInfo.systemUptime)
            )
        )
    }

    private var architecture: String {
        if sysctlInteger("hw.optional.arm64") == 1 { return "arm64" }
        return sysctlString("hw.machine") ?? "Unavailable"
    }

    private func operatingSystemVersion(_ version: OperatingSystemVersion) -> String {
        if version.patchVersion > 0 {
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
        return "\(version.majorVersion).\(version.minorVersion)"
    }

    private func modelName(computerName: String, identifier: String) -> String {
        let families = ["MacBook Pro", "MacBook Air", "Mac Studio", "Mac mini", "Mac Pro", "iMac"]
        if let family = families.first(where: { computerName.localizedCaseInsensitiveContains($0) }) {
            return family
        }
        if identifier.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if identifier.hasPrefix("MacBookAir") { return "MacBook Air" }
        if identifier.hasPrefix("Macmini") { return "Mac mini" }
        if identifier.hasPrefix("MacPro") { return "Mac Pro" }
        if identifier.hasPrefix("iMac") { return "iMac" }
        return "Mac"
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private func sysctlInteger(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

@MainActor
struct DisplayInformationReader {
    func read() -> [DisplaySnapshot] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
            let refreshRate = mode.refreshRate > 0 ? Int(mode.refreshRate.rounded()) : nil
            return DisplaySnapshot(
                id: displayID,
                name: screen.localizedName,
                pixelWidth: mode.pixelWidth,
                pixelHeight: mode.pixelHeight,
                scaledWidth: mode.width,
                scaledHeight: mode.height,
                refreshRate: refreshRate,
                isMain: CGDisplayIsMain(displayID) != 0,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                isRetina: mode.pixelWidth > mode.width || mode.pixelHeight > mode.height
            )
        }
        .sorted { lhs, rhs in
            if lhs.isMain != rhs.isMain { return lhs.isMain }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
