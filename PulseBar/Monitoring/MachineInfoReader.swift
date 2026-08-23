import Darwin
import Foundation

struct MachineInfoReader {
    func read() -> MachineInfo {
        MachineInfo(
            name: Host.current().localizedName ?? "Mac",
            processor: sysctlString("machdep.cpu.brand_string") ?? architectureName,
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        )
    }

    private var architectureName: String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel"
        #else
        return "Mac"
        #endif
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
