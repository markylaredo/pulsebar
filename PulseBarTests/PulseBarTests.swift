import XCTest
@testable import PulseBar

final class PulseBarTests: XCTestCase {
    func testCPUUsageUsesTickDeltas() {
        let previous = CPUTicks(user: 100, system: 100, idle: 800, nice: 0)
        let current = CPUTicks(user: 150, system: 125, idle: 875, nice: 0)
        XCTAssertEqual(CounterMath.cpuUsage(previous: previous, current: current) ?? -1, 0.5, accuracy: 0.0001)
    }

    func testCPUBreakdownUsesTickDeltas() throws {
        let previous = CPUTicks(user: 100, system: 100, idle: 800, nice: 0)
        let current = CPUTicks(user: 150, system: 125, idle: 875, nice: 0)
        let breakdown = try XCTUnwrap(CounterMath.cpuBreakdown(previous: previous, current: current))

        XCTAssertEqual(breakdown.user, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(breakdown.system, 1.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(breakdown.idle, 0.5, accuracy: 0.0001)
        XCTAssertEqual(breakdown.totalUsage, 0.5, accuracy: 0.0001)
    }

    func testPerformanceHistoriesUseBoundedExtendedCapacity() {
        let histories = MetricHistories()
        XCTAssertEqual(histories.cpu.capacity, 180)
        XCTAssertEqual(histories.memory.capacity, 180)
        XCTAssertEqual(histories.diskRead.capacity, 180)
        XCTAssertEqual(histories.download.capacity, 180)
    }

    func testMemoryPressureMapping() {
        XCTAssertEqual(MemoryPressureStats(.normal), .normal)
        XCTAssertEqual(MemoryPressureStats(.warning), .elevated)
        XCTAssertEqual(MemoryPressureStats(.critical), .critical)
    }

    func testCounterRateAndResetConditions() {
        XCTAssertEqual(CounterMath.rate(previous: 1_000_000, current: 4_000_000, elapsed: 1), 3_000_000)
        XCTAssertNil(CounterMath.rate(previous: 4_000_000, current: 1_000_000, elapsed: 1))
        XCTAssertNil(CounterMath.rate(previous: 1, current: 2, elapsed: 0))
        XCTAssertNil(CounterMath.rate(previous: 1, current: 2, elapsed: .infinity))
        XCTAssertNil(CounterMath.rate(previous: 1, current: 2, elapsed: .nan))
    }

    func testMetricHistoryIsBounded() {
        var history = MetricHistory(capacity: 3)
        [1.0, 2.0, 3.0, 4.0].forEach { history.append($0) }
        XCTAssertEqual(history.samples, [2, 3, 4])
    }

    func testMetricHistorySanitizesInvalidSamples() {
        var history = MetricHistory(capacity: 4)
        [-1, .infinity, .nan, 2].forEach { history.append($0) }
        XCTAssertEqual(history.samples, [0, 0, 0, 2])
    }

    func testDashboardOpacityLevelIsNormalizedAndClamped() {
        XCTAssertEqual(DashboardAppearance.opacity(for: 8), 0.8, accuracy: 0.0001)
        XCTAssertEqual(DashboardAppearance.opacity(for: -1), 0.1, accuracy: 0.0001)
        XCTAssertEqual(DashboardAppearance.opacity(for: 12), 1, accuracy: 0.0001)
        XCTAssertEqual(DashboardAppearance.glassTintOpacity(for: 1), 0, accuracy: 0.0001)
        XCTAssertEqual(DashboardAppearance.glassTintOpacity(for: 7), 0.1333, accuracy: 0.0001)
        XCTAssertEqual(DashboardAppearance.glassTintOpacity(for: 10), 0.2, accuracy: 0.0001)
    }

    func testDashboardShortcutStorageRoundTrips() {
        let shortcut = DashboardShortcut(
            keyCode: 35,
            modifiers: [.control, .option, .shift],
            keyName: "P"
        )

        XCTAssertEqual(DashboardShortcut(storageValue: shortcut.storageValue), shortcut)
        XCTAssertEqual(shortcut.displayName, "⌃⌥⇧P")
        XCTAssertNil(DashboardShortcut(storageValue: ""))
        XCTAssertNil(DashboardShortcut(storageValue: "invalid"))
    }

    func testFormatting() {
        XCTAssertEqual(MetricFormatter.percentage(0.414), "41%")
        XCTAssertEqual(MetricFormatter.processPercentage(42.14), "42.1%")
        XCTAssertEqual(MetricFormatter.bytes(1_000_000), "1 MB")
        XCTAssertEqual(MetricFormatter.memory(25_769_803_776), "24.00 GB")
        XCTAssertEqual(MetricFormatter.memory(0), "0 B")
        XCTAssertEqual(MetricFormatter.rate(3_400_000), "3.4 MB/s")
        XCTAssertEqual(MetricFormatter.compactRate(420_000), "420K")
        XCTAssertEqual(MetricFormatter.count(8_704_999), "8,704,999")
        XCTAssertEqual(MetricFormatter.packetRate(1.6), "2 pkt/s")
        XCTAssertEqual(MetricFormatter.uptime(3 * 86_400 + 14 * 3_600), "3d 14h")
        XCTAssertEqual(MetricFormatter.uptime(5 * 3_600 + 32 * 60), "5h 32m")
        XCTAssertEqual(MetricFormatter.bytes(1_020_000_000_000), "1.0 TB")
    }

    func testVolumeCapacityAccountingAndStatus() {
        let volume = VolumeSnapshot(
            id: "test",
            name: "Test Disk",
            mountPath: "/Volumes/Test Disk",
            totalCapacity: 1_000,
            availableCapacity: 150,
            filesystem: "APFS",
            isReadOnly: false,
            isLocal: true,
            isInternal: false,
            isRemovable: false,
            isPrimary: false
        )

        XCTAssertEqual(volume.usedCapacity, 850)
        XCTAssertEqual(volume.usage ?? -1, 0.85, accuracy: 0.0001)
        XCTAssertEqual(volume.capacityStatus, .gettingFull)
        XCTAssertEqual(volume.kind, .externalDrive)
    }

    func testStorageCapacityStatusThresholds() {
        XCTAssertEqual(StorageCapacityStatus(usage: 0.79), .normal)
        XCTAssertEqual(StorageCapacityStatus(usage: 0.8), .gettingFull)
        XCTAssertEqual(StorageCapacityStatus(usage: 0.9), .gettingFull)
        XCTAssertEqual(StorageCapacityStatus(usage: 0.91), .lowFreeSpace)
        XCTAssertEqual(StorageCapacityStatus(usage: nil), .unavailable)
    }

    func testProcessCPUPercentageUsesCumulativeTimeDeltas() {
        let previous = ProcessCPUSample(
            totalTimeNanoseconds: 1_000_000_000,
            timestampNanoseconds: 5_000_000_000
        )
        let current = ProcessCPUSample(
            totalTimeNanoseconds: 1_500_000_000,
            timestampNanoseconds: 6_000_000_000
        )

        XCTAssertEqual(
            ProcessCPUCalculator.percentage(previous: previous, current: current),
            50,
            accuracy: 0.0001
        )
        XCTAssertEqual(ProcessCPUCalculator.percentage(previous: nil, current: current), 0)
    }

    func testProcessSearchMatchesNameAndPID() {
        let process = ProcessSnapshot(
            id: ProcessIdentity(pid: 4_821, startTimeMicroseconds: 100),
            name: "Xcode",
            cpuUsage: 42.1,
            residentMemory: 1_000,
            threadCount: 12,
            architecture: "arm64",
            executablePath: "/Applications/Xcode.app/Contents/MacOS/Xcode",
            launchDate: .distantPast,
            canTerminate: true
        )

        XCTAssertTrue(process.matches("xCo"))
        XCTAssertTrue(process.matches("4821"))
        XCTAssertFalse(process.matches("Safari"))
    }

    func testNetworkEndpointFormattingSupportsIPv4AndIPv6() {
        XCTAssertEqual(
            NetworkEndpoint(address: "192.168.1.42", port: 5_432).displayName,
            "192.168.1.42:5432"
        )
        XCTAssertEqual(
            NetworkEndpoint(address: "2607:f8b0:4005::200e", port: 443).displayName,
            "[2607:f8b0:4005::200e]:443"
        )
        XCTAssertEqual(NetworkEndpoint(address: "0.0.0.0", port: 3_000).displayName, "*:3000")
    }

    func testNetworkConnectionSearchAndFilters() {
        let connection = networkConnection(
            processName: "postgres",
            pid: 4_821,
            transport: .tcp,
            local: NetworkEndpoint(address: "127.0.0.1", port: 5_432),
            remote: NetworkEndpoint(address: "127.0.0.1", port: 61_243),
            state: .established
        )

        XCTAssertTrue(connection.matches("POST"))
        XCTAssertTrue(connection.matches("4821"))
        XCTAssertTrue(connection.matches("5432"))
        XCTAssertTrue(connection.matches("127.0.0"))
        XCTAssertFalse(connection.matches("Safari"))
        XCTAssertTrue(NetworkConnectionFilter.all.includes(connection))
        XCTAssertTrue(NetworkConnectionFilter.tcp.includes(connection))
        XCTAssertTrue(NetworkConnectionFilter.established.includes(connection))
        XCTAssertFalse(NetworkConnectionFilter.udp.includes(connection))
        XCTAssertFalse(NetworkConnectionFilter.listening.includes(connection))
    }

    func testUDPBoundSocketIsListeningWithoutTCPState() {
        let socket = networkConnection(
            processName: "mDNSResponder",
            pid: 123,
            transport: .udp,
            local: NetworkEndpoint(address: "0.0.0.0", port: 5_353),
            remote: nil,
            state: nil
        )

        XCTAssertNil(socket.state)
        XCTAssertEqual(socket.stateName, "Bound")
        XCTAssertTrue(socket.isListening)
        XCTAssertTrue(NetworkConnectionFilter.listening.includes(socket))
        XCTAssertFalse(NetworkConnectionFilter.established.includes(socket))
    }

    func testShareSafeIPAddressClassification() {
        XCTAssertTrue(ShareSafeIPAddress.contains("192.168.1.42"))
        XCTAssertTrue(ShareSafeIPAddress.contains("172.31.4.8"))
        XCTAssertTrue(ShareSafeIPAddress.contains("10.0.0.5"))
        XCTAssertTrue(ShareSafeIPAddress.contains("100.64.0.12"))
        XCTAssertTrue(ShareSafeIPAddress.contains("fe80::1%en0"))
        XCTAssertTrue(ShareSafeIPAddress.contains("fd00::12"))
        XCTAssertFalse(ShareSafeIPAddress.contains("8.8.8.8"))
        XCTAssertFalse(ShareSafeIPAddress.contains("2606:4700:4700::1111"))
    }

    func testSystemReportExcludesSensitiveAndPublicNetworkValues() {
        let system = SystemInformationSnapshot(
            hardware: HardwareInformation(
                modelName: "MacBook Pro",
                modelIdentifier: "MacBookPro99,1",
                chip: "Apple Test Chip",
                architecture: "arm64",
                physicalMemory: 32 * 1_024 * 1_024 * 1_024,
                logicalProcessorCount: 10
            ),
            operatingSystem: OperatingSystemInformation(
                version: "26.1",
                build: "25B123",
                kernel: "Darwin 25.1.0",
                computerName: "Private Person's Mac",
                hostname: "private-person.local",
                bootDate: .distantPast
            )
        )
        let volume = VolumeSnapshot(
            id: "private-volume-id",
            name: "Macintosh HD",
            mountPath: "/Users/private-person",
            totalCapacity: 1_000,
            availableCapacity: 400,
            filesystem: "APFS",
            isReadOnly: false,
            isLocal: true,
            isInternal: true,
            isRemovable: false,
            isPrimary: true
        )
        let interface = NetworkInterfaceSnapshot(
            id: "en0",
            displayName: "Wi-Fi",
            kind: .wifi,
            ipv4Addresses: ["8.8.8.8", "192.168.1.42"],
            ipv6Addresses: ["2606:4700:4700::1111"],
            macAddress: "00:11:22:33:44:55",
            isUp: true,
            isRunning: true,
            isPrimary: true
        )

        let report = SystemReportFormatter.report(
            system: system,
            displays: [],
            battery: nil,
            volumes: [volume],
            interfaces: [interface],
            uptime: 3 * 86_400 + 14 * 3_600
        )

        XCTAssertTrue(report.contains("PulseBar System Report"))
        XCTAssertTrue(report.contains("192.168.1.42"))
        XCTAssertTrue(report.contains("3d 14h"))
        XCTAssertFalse(report.contains("Private Person"))
        XCTAssertFalse(report.contains("private-person.local"))
        XCTAssertFalse(report.contains("/Users/private-person"))
        XCTAssertFalse(report.contains("8.8.8.8"))
        XCTAssertFalse(report.contains("2606:4700:4700::1111"))
        XCTAssertFalse(report.contains("00:11:22:33:44:55"))
    }

    func testActivityMonitorNetworkAccounting() {
        let previous = NetworkCounters(receivedBytes: 1_000, sentBytes: 2_000, receivedPackets: 100, sentPackets: 200)
        let current = NetworkCounters(receivedBytes: 1_600, sentBytes: 3_000, receivedPackets: 120, sentPackets: 208)
        let stats = NetworkAccounting.calculate(previous: previous, current: current, elapsed: 2)

        XCTAssertEqual(stats.downloadRate, 300)
        XCTAssertEqual(stats.uploadRate, 500)
        XCTAssertEqual(stats.packetsReceivedRate, 10)
        XCTAssertEqual(stats.packetsSentRate, 4)
        XCTAssertEqual(stats.totalReceived, 1_600)
        XCTAssertEqual(stats.totalTransmitted, 3_000)
        XCTAssertEqual(stats.totalPacketsReceived, 120)
        XCTAssertEqual(stats.totalPacketsSent, 208)
    }

    private func networkConnection(
        processName: String,
        pid: pid_t,
        transport: NetworkTransport,
        local: NetworkEndpoint,
        remote: NetworkEndpoint?,
        state: NetworkConnectionState?
    ) -> NetworkConnectionSnapshot {
        let identity = ProcessIdentity(pid: pid, startTimeMicroseconds: 100)
        return NetworkConnectionSnapshot(
            id: NetworkConnectionID(
                pid: pid,
                socketHandle: 1,
                transport: transport,
                local: local,
                remote: remote
            ),
            processIdentity: identity,
            processName: processName,
            executablePath: nil,
            transport: transport,
            local: local,
            remote: remote,
            state: state,
            interfaceName: "lo0"
        )
    }

    func testNetworkCounterResetDoesNotCreateFalseTrafficSpike() {
        let previous = NetworkCounters(receivedBytes: 10_000, sentBytes: 20_000, receivedPackets: 100, sentPackets: 200)
        let reset = NetworkCounters(receivedBytes: 10, sentBytes: 20, receivedPackets: 1, sentPackets: 2)
        let stats = NetworkAccounting.calculate(previous: previous, current: reset, elapsed: 1)

        XCTAssertEqual(stats.downloadRate, 0)
        XCTAssertEqual(stats.uploadRate, 0)
        XCTAssertEqual(stats.packetsReceivedRate, 0)
        XCTAssertEqual(stats.packetsSentRate, 0)
    }

    func testActivityMonitorMemoryAccounting() {
        let accounting = MemoryAccounting.calculate(
            physical: 1_000,
            pageSize: 10,
            freePages: 5,
            fileBackedPages: 20,
            purgeablePages: 5
        )

        XCTAssertEqual(accounting.cached, 250)
        XCTAssertEqual(accounting.available, 300)
        XCTAssertEqual(accounting.used, 700)
    }

    func testMenuBarPresentationIncludesEnabledMetrics() throws {
        let suiteName = "PulseBarTests.MenuBarPresentation"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: SettingsKey.showCPU)
        defaults.set(true, forKey: SettingsKey.showMemory)
        defaults.set(true, forKey: SettingsKey.showDownload)
        defaults.set(true, forKey: SettingsKey.showUpload)

        var metrics = SystemMetrics()
        metrics.cpu.totalUsage = 0.12
        metrics.memory.used = metrics.memory.physical / 2
        metrics.network.downloadRate = 3_400_000
        metrics.network.uploadRate = 420_000

        XCTAssertEqual(
            MenuBarPresentation.make(metrics: metrics, defaults: defaults).text,
            "CPU 12% · RAM 50% · ↓3.4M · ↑420K"
        )
    }

    func testMenuBarPresentationUsesSavedMetricOrder() throws {
        let suiteName = "PulseBarTests.MenuBarPresentation.Order"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: SettingsKey.showCPU)
        defaults.set(true, forKey: SettingsKey.showMemory)
        defaults.set(true, forKey: SettingsKey.showDownload)
        defaults.set(true, forKey: SettingsKey.showUpload)
        defaults.set("upload,cpu,memory,download", forKey: SettingsKey.menuBarMetricOrder)

        var metrics = SystemMetrics()
        metrics.cpu.totalUsage = 0.12
        metrics.memory.used = metrics.memory.physical / 2
        metrics.network.downloadRate = 3_400_000
        metrics.network.uploadRate = 420_000

        let presentation = MenuBarPresentation.make(metrics: metrics, defaults: defaults)
        XCTAssertEqual(presentation.text, "↑420K · CPU 12% · RAM 50% · ↓3.4M")
        XCTAssertEqual(presentation.parts.map(\.id), [.upload, .cpu, .memory, .download])
    }

    func testMenuBarMetricOrderRepairsDuplicatesAndMissingItems() {
        XCTAssertEqual(
            MenuBarMetric.ordered(from: "upload,cpu,invalid,upload"),
            [.upload, .cpu, .memory, .download, .diskRead, .diskWrite, .battery]
        )
    }

    func testCompactMenuBarUsesRAMIconAndStableWidth() throws {
        let suiteName = "PulseBarTests.MenuBarPresentation.Compact"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: SettingsKey.compactMenuBar)
        defaults.set(true, forKey: SettingsKey.showCPU)
        defaults.set(true, forKey: SettingsKey.showMemory)
        defaults.set(true, forKey: SettingsKey.showDownload)
        defaults.set(true, forKey: SettingsKey.showUpload)

        var metrics = SystemMetrics()
        metrics.network.downloadRate = 0
        metrics.network.uploadRate = 0
        let idle = MenuBarPresentation.make(metrics: metrics, defaults: defaults)

        metrics.cpu.totalUsage = 1
        metrics.memory.used = metrics.memory.physical
        metrics.network.downloadRate = 99_900_000
        metrics.network.uploadRate = 9_900_000_000
        let busy = MenuBarPresentation.make(metrics: metrics, defaults: defaults)

        let memoryPart = try XCTUnwrap(busy.parts.first { $0.id == .memory })
        XCTAssertEqual(memoryPart.prefix, "")
        XCTAssertEqual(memoryPart.symbolName, "memorychip")
        XCTAssertEqual(idle.preferredWidth, busy.preferredWidth)
        XCTAssertEqual(busy.widthBehavior, .fixed)
    }

    func testMenuBarSupportsDynamicWidthPreference() throws {
        let suiteName = "PulseBarTests.MenuBarPresentation.DynamicWidth"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MenuBarWidthBehavior.dynamic.rawValue, forKey: SettingsKey.menuBarWidthBehavior)

        let presentation = MenuBarPresentation.make(metrics: SystemMetrics(), defaults: defaults)

        XCTAssertEqual(presentation.widthBehavior, .dynamic)
    }
}
