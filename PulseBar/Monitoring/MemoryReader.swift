import Darwin
import Foundation

struct MemoryReader {
    func read() -> MemoryStats {
        let host = mach_host_self()
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return MemoryStats() }

        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return MemoryStats() }

        let page = UInt64(pageSize)
        let appPages = UInt64(info.internal_page_count > info.purgeable_count ? info.internal_page_count - info.purgeable_count : 0)
        let wired = UInt64(info.wire_count) * page
        let compressed = UInt64(info.compressor_page_count) * page
        let app = appPages * page
        let physical = ProcessInfo.processInfo.physicalMemory
        let accounting = MemoryAccounting.calculate(
            physical: physical,
            pageSize: page,
            freePages: UInt64(info.free_count),
            fileBackedPages: UInt64(info.external_page_count),
            purgeablePages: UInt64(info.purgeable_count)
        )
        let swap = readSwapUsage()
        return MemoryStats(
            physical: physical,
            used: accounting.used,
            available: accounting.available,
            appMemory: app,
            wired: wired,
            compressed: compressed,
            cached: accounting.cached,
            swapUsed: swap?.used ?? 0,
            swapTotal: swap?.total ?? 0
        )
    }

    private func readSwapUsage() -> (used: UInt64, total: UInt64)? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return (usage.xsu_used, usage.xsu_total)
    }
}

struct MemoryAccounting: Equatable, Sendable {
    let used: UInt64
    let available: UInt64
    let cached: UInt64

    static func calculate(
        physical: UInt64,
        pageSize: UInt64,
        freePages: UInt64,
        fileBackedPages: UInt64,
        purgeablePages: UInt64
    ) -> Self {
        let cachedPages = fileBackedPages.addingReportingOverflow(purgeablePages)
        let safeCachedPages = cachedPages.overflow ? UInt64.max : cachedPages.partialValue
        let cached = bytes(pages: safeCachedPages, pageSize: pageSize)
        let free = bytes(pages: freePages, pageSize: pageSize)
        let reclaimable = free.addingReportingOverflow(cached)
        let available = min(physical, reclaimable.overflow ? UInt64.max : reclaimable.partialValue)
        return Self(used: physical - available, available: available, cached: min(physical, cached))
    }

    private static func bytes(pages: UInt64, pageSize: UInt64) -> UInt64 {
        let result = pages.multipliedReportingOverflow(by: pageSize)
        return result.overflow ? UInt64.max : result.partialValue
    }
}
