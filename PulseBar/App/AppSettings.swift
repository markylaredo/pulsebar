import ServiceManagement
import SwiftUI

enum SettingsKey {
    static let refreshPreset = "refreshPreset"
    static let appearance = "appearance"
    static let dashboardLiquidGlass = "dashboardLiquidGlass"
    static let dashboardBackgroundTint = "dashboardBackgroundTint"
    static let dashboardOpacity = "dashboardOpacity"
    static let dashboardPinned = "dashboardPinned"
    static let compactMenuBar = "compactMenuBar"
    static let menuBarWidthBehavior = "menuBarWidthBehavior"
    static let showCPU = "showCPU"
    static let showMemory = "showMemory"
    static let showDownload = "showDownload"
    static let showUpload = "showUpload"
    static let showDiskRead = "showDiskRead"
    static let showDiskWrite = "showDiskWrite"
    static let showBattery = "showBattery"
    static let monitorCPU = "monitorCPU"
    static let monitorMemory = "monitorMemory"
    static let monitorNetwork = "monitorNetwork"
    static let monitorDisk = "monitorDisk"
    static let monitorBattery = "monitorBattery"
    static let monitorThermal = "monitorThermal"
    static let networkDisplayMode = "networkDisplayMode"
    static let menuBarMetricOrder = "menuBarMetricOrder"
}

enum DashboardBackgroundTint: String, CaseIterable, Identifiable {
    case black
    case white

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .black: .black
        case .white: .white
        }
    }
}

enum DashboardAppearance {
    static let defaultOpacityLevel = 8.0

    static func opacity(for level: Double) -> Double {
        min(max(level, 1), 10) / 10
    }

    static func glassTintOpacity(for level: Double) -> Double {
        let clampedLevel = min(max(level, 1), 10)
        return ((clampedLevel - 1) / 9) * 0.2
    }
}

enum MenuBarWidthBehavior: String, CaseIterable, Identifiable {
    case fixed
    case dynamic

    var id: Self { self }

    var title: String {
        switch self {
        case .fixed: "Fixed"
        case .dynamic: "Dynamic"
        }
    }
}

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case cpu
    case memory
    case download
    case upload
    case diskRead
    case diskWrite
    case battery

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .download: "Download"
        case .upload: "Upload"
        case .diskRead: "Disk Read"
        case .diskWrite: "Disk Write"
        case .battery: "Battery"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "waveform.path.ecg"
        case .memory: "memorychip"
        case .download: "arrow.down"
        case .upload: "arrow.up"
        case .diskRead: "arrow.down.circle"
        case .diskWrite: "arrow.up.circle"
        case .battery: "battery.75percent"
        }
    }

    var visibilityKey: String {
        switch self {
        case .cpu: SettingsKey.showCPU
        case .memory: SettingsKey.showMemory
        case .download: SettingsKey.showDownload
        case .upload: SettingsKey.showUpload
        case .diskRead: SettingsKey.showDiskRead
        case .diskWrite: SettingsKey.showDiskWrite
        case .battery: SettingsKey.showBattery
        }
    }

    static var defaultOrderValue: String {
        allCases.map(\.rawValue).joined(separator: ",")
    }

    static func ordered(from storedValue: String?) -> [Self] {
        var seen = Set<Self>()
        let stored = (storedValue ?? "")
            .split(separator: ",")
            .compactMap { Self(rawValue: String($0)) }
            .filter { seen.insert($0).inserted }
        return stored + allCases.filter { !seen.contains($0) }
    }

    static func encode(_ metrics: [Self]) -> String {
        metrics.map(\.rawValue).joined(separator: ",")
    }
}

enum NetworkDisplayMode: String, CaseIterable, Identifiable {
    case data
    case packets

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum RefreshPreset: String, CaseIterable, Identifiable {
    case lowPower, normal, fast

    var id: Self { self }
    var interval: Duration {
        switch self {
        case .lowPower: .seconds(3)
        case .normal: .seconds(1)
        case .fast: .milliseconds(500)
        }
    }
    var title: String {
        switch self {
        case .lowPower: "Low Power"
        case .normal: "Normal"
        case .fast: "Fast"
        }
    }
    var detail: String {
        switch self {
        case .lowPower: "3 seconds"
        case .normal: "1 second"
        case .fast: "0.5 second"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class LaunchAtLoginController {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    var errorMessage: String?

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            errorMessage = nil
        } catch {
            refresh()
            errorMessage = error.localizedDescription
        }
    }
}
