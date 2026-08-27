import Foundation

enum VolumeKind: String, Sendable {
    case internalDrive = "Internal"
    case externalDrive = "External"
    case removable = "Removable"
    case network = "Network"
    case unknown = "Unavailable"
}

enum StorageCapacityStatus: String, Sendable {
    case normal = "Normal"
    case gettingFull = "Getting Full"
    case lowFreeSpace = "Low Free Space"
    case unavailable = "Unavailable"

    init(usage: Double?) {
        guard let usage, usage.isFinite else {
            self = .unavailable
            return
        }
        if usage < 0.8 {
            self = .normal
        } else if usage <= 0.9 {
            self = .gettingFull
        } else {
            self = .lowFreeSpace
        }
    }
}

struct VolumeSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let mountPath: String
    let totalCapacity: UInt64?
    let availableCapacity: UInt64?
    let filesystem: String?
    let isReadOnly: Bool?
    let isLocal: Bool?
    let isInternal: Bool?
    let isRemovable: Bool?
    let isPrimary: Bool

    var sortName: String { name.localizedLowercase }
    var capacitySortValue: UInt64 { totalCapacity ?? 0 }
    var availableSortValue: UInt64 { availableCapacity ?? 0 }

    var usedCapacity: UInt64? {
        guard let totalCapacity, let availableCapacity else { return nil }
        return totalCapacity >= availableCapacity ? totalCapacity - availableCapacity : 0
    }

    var usedSortValue: UInt64 { usedCapacity ?? 0 }

    var usage: Double? {
        guard let totalCapacity, totalCapacity > 0, let usedCapacity else { return nil }
        return Double(usedCapacity) / Double(totalCapacity)
    }

    var capacityStatus: StorageCapacityStatus {
        StorageCapacityStatus(usage: usage)
    }

    var kind: VolumeKind {
        if isLocal == false { return .network }
        if isRemovable == true { return .removable }
        if isInternal == true { return .internalDrive }
        if isInternal == false { return .externalDrive }
        return .unknown
    }
}

struct StorageInventory: Sendable {
    var primary = StorageStats()
    var volumes: [VolumeSnapshot] = []
}
