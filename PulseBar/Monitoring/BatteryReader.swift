import Foundation
import IOKit.ps

struct BatteryReader {
    func read() -> BatteryStats? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue ?? 0
            let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue ?? 100
            let charging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let powerSource = description[kIOPSPowerSourceStateKey] as? String
            let timeKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let minutes = (description[timeKey] as? NSNumber)?.intValue
            let cycleCount = (description["CycleCount"] as? NSNumber)?.intValue
            let condition = batteryCondition(description["BatteryHealth"])
            return BatteryStats(
                percentage: maximum > 0 ? min(max(current / maximum, 0), 1) : 0,
                isCharging: charging,
                isConnectedToPower: powerSource == kIOPSACPowerValue,
                timeRemainingMinutes: (minutes ?? 0) > 0 ? minutes : nil,
                cycleCount: cycleCount,
                condition: condition
            )
        }
        return nil
    }

    private func batteryCondition(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty {
            return value.localizedCaseInsensitiveCompare("Good") == .orderedSame ? "Normal" : value
        }
        guard let value = (value as? NSNumber)?.intValue else { return nil }
        switch value {
        case 3: return "Normal"
        case 2: return "Fair"
        case 1: return "Poor"
        default: return nil
        }
    }
}
