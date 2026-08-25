import AppKit
import Foundation
import Observation

private actor CPUReaderWorker {
    private var reader = CPUReader()

    func read() -> CPUStats { reader.read() }
    func reset() { reader.reset() }
}

private actor MemoryReaderWorker {
    private let reader = MemoryReader()

    func read() -> MemoryStats { reader.read() }
}

private actor NetworkReaderWorker {
    private var reader = NetworkReader()

    func read() -> NetworkStats { reader.read() }
    func reset() { reader.reset() }
}

private actor DiskReaderWorker {
    private var reader = DiskReader()

    func read() -> DiskStats { reader.read() }
    func reset() { reader.reset() }
}

private actor StorageReaderWorker {
    private let reader = StorageReader()

    func read() -> StorageStats { reader.read() }
}

private actor BatteryReaderWorker {
    private let reader = BatteryReader()

    func read() -> BatteryStats? { reader.read() }
}

private actor ThermalReaderWorker {
    func read() -> ThermalStats { ThermalStats(ProcessInfo.processInfo.thermalState) }
}

final class MetricsCollector: Sendable {
    private let cpuReader = CPUReaderWorker()
    private let memoryReader = MemoryReaderWorker()
    private let networkReader = NetworkReaderWorker()
    private let diskReader = DiskReaderWorker()
    private let storageReader = StorageReaderWorker()
    private let batteryReader = BatteryReaderWorker()
    private let thermalReader = ThermalReaderWorker()

    func cpu() async -> CPUStats { await cpuReader.read() }
    func memory() async -> MemoryStats { await memoryReader.read() }
    func network() async -> NetworkStats { await networkReader.read() }
    func disk() async -> DiskStats { await diskReader.read() }
    func storage() async -> StorageStats { await storageReader.read() }
    func battery() async -> BatteryStats? { await batteryReader.read() }
    func thermal() async -> ThermalStats { await thermalReader.read() }

    func resetBaselines() async {
        async let cpu: Void = cpuReader.reset()
        async let network: Void = networkReader.reset()
        async let disk: Void = diskReader.reset()
        _ = await (cpu, network, disk)
    }
}

@MainActor
@Observable
final class SystemMonitor {
    private(set) var metrics = SystemMetrics()
    private(set) var histories = MetricHistories()
    private(set) var machineInfo = MachineInfoReader().read()
    private(set) var lastUpdated: Date?
    private let collector = MetricsCollector()
    private var monitoringTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        registerDefaults()
        observeSleepAndWake()
        start()
    }

    func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoop()
        }
    }

    func restart() {
        monitoringTask?.cancel()
        monitoringTask = nil
        start()
    }

    private func runLoop() async {
        var cycle = 0
        while !Task.isCancelled {
            await refresh(cycle: cycle)
            cycle &+= 1
            let rawPreset = UserDefaults.standard.string(forKey: SettingsKey.refreshPreset) ?? RefreshPreset.normal.rawValue
            let preset = RefreshPreset(rawValue: rawPreset) ?? .normal
            do { try await Task.sleep(for: preset.interval) } catch { return }
        }
    }

    private func refresh(cycle: Int) async {
        let defaults = UserDefaults.standard
        async let cpu = defaults.bool(forKey: SettingsKey.monitorCPU) ? collector.cpu() : nil
        async let network = defaults.bool(forKey: SettingsKey.monitorNetwork) ? collector.network() : nil
        async let memory = cycle.isMultiple(of: 2) && defaults.bool(forKey: SettingsKey.monitorMemory) ? collector.memory() : nil
        async let disk = cycle.isMultiple(of: 2) && defaults.bool(forKey: SettingsKey.monitorDisk) ? collector.disk() : nil
        async let thermal = cycle.isMultiple(of: 3) && defaults.bool(forKey: SettingsKey.monitorThermal) ? collector.thermal() : nil
        async let battery = cycle.isMultiple(of: 5) && defaults.bool(forKey: SettingsKey.monitorBattery) ? collector.battery() : nil
        async let storage = cycle.isMultiple(of: 30) ? collector.storage() : nil

        if let cpu = await cpu { metrics.cpu = cpu; histories.cpu.append(cpu.totalUsage) }
        if let memory = await memory { metrics.memory = memory; histories.memory.append(memory.usage) }
        if let network = await network {
            metrics.network = network
            histories.download.append(network.downloadRate)
            histories.upload.append(network.uploadRate)
            histories.packetsReceived.append(network.packetsReceivedRate)
            histories.packetsSent.append(network.packetsSentRate)
        }
        if let disk = await disk {
            metrics.disk = disk
            histories.diskRead.append(disk.readRate)
            histories.diskWrite.append(disk.writeRate)
        }
        if let thermal = await thermal { metrics.thermal = thermal }
        if cycle.isMultiple(of: 5), defaults.bool(forKey: SettingsKey.monitorBattery) { metrics.battery = await battery }
        if let storage = await storage { metrics.storage = storage }
        lastUpdated = .now
    }

    private func observeSleepAndWake() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.monitoringTask?.cancel(); self?.monitoringTask = nil }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.collector.resetBaselines()
                self.start()
            }
        })
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.refreshPreset: RefreshPreset.normal.rawValue,
            SettingsKey.appearance: AppAppearance.system.rawValue,
            SettingsKey.dashboardLiquidGlass: true,
            SettingsKey.dashboardBackgroundTint: DashboardBackgroundTint.black.rawValue,
            SettingsKey.dashboardOpacity: DashboardAppearance.defaultOpacityLevel,
            SettingsKey.dashboardPinned: true,
            SettingsKey.dashboardShortcut: DashboardShortcut.defaultValue.storageValue,
            SettingsKey.compactMenuBar: false,
            SettingsKey.menuBarWidthBehavior: MenuBarWidthBehavior.fixed.rawValue,
            SettingsKey.showCPU: true,
            SettingsKey.showMemory: true,
            SettingsKey.showDownload: true,
            SettingsKey.showUpload: true,
            SettingsKey.showDiskRead: false,
            SettingsKey.showDiskWrite: false,
            SettingsKey.showBattery: false,
            SettingsKey.monitorCPU: true,
            SettingsKey.monitorMemory: true,
            SettingsKey.monitorNetwork: true,
            SettingsKey.monitorDisk: true,
            SettingsKey.monitorBattery: true,
            SettingsKey.monitorThermal: true,
            SettingsKey.networkDisplayMode: NetworkDisplayMode.data.rawValue,
            SettingsKey.menuBarMetricOrder: MenuBarMetric.defaultOrderValue
        ])
    }
}
