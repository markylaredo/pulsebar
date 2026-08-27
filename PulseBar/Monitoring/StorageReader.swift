import Foundation

struct StorageReader {
    private let resourceKeys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeUUIDStringKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeLocalizedFormatDescriptionKey,
        .volumeIsReadOnlyKey,
        .volumeIsLocalKey,
        .volumeIsInternalKey,
        .volumeIsRemovableKey,
        .volumeIsBrowsableKey
    ]

    func read() -> StorageInventory {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        var mountedURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(resourceKeys),
            options: [.skipHiddenVolumes]
        ) ?? []

        if !mountedURLs.contains(where: { $0.standardizedFileURL.path == root.path }) {
            mountedURLs.insert(root, at: 0)
        }

        var seenIdentities = Set<String>()
        let volumes = mountedURLs.compactMap(snapshot)
            .filter { seenIdentities.insert($0.id).inserted }
            .sorted {
                if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
                let comparison = $0.name.localizedStandardCompare($1.name)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return $0.mountPath < $1.mountPath
            }

        guard let primary = volumes.first(where: \.isPrimary) else {
            return StorageInventory(volumes: volumes)
        }
        return StorageInventory(
            primary: StorageStats(
                total: primary.totalCapacity ?? 0,
                available: primary.availableCapacity ?? 0
            ),
            volumes: volumes
        )
    }

    private func snapshot(for url: URL) -> VolumeSnapshot? {
        let mountPath = url.standardizedFileURL.path

        // APFS exposes several implementation volumes under /System/Volumes.
        // They share capacity with the startup disk and are not useful as separate rows.
        guard mountPath == "/" || !mountPath.hasPrefix("/System/Volumes/") else { return nil }
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
        guard mountPath == "/" || values.volumeIsBrowsable != false else { return nil }

        let total = values.volumeTotalCapacity.map { UInt64(max(0, $0)) }
        let availableForImportantUsage = values.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }
        let available = availableForImportantUsage
            ?? values.volumeAvailableCapacity.map { UInt64(max(0, $0)) }
        let clampedAvailable = total.map { min($0, available ?? $0) } ?? available
        let fallbackName = mountPath == "/" ? "Startup Disk" : url.lastPathComponent
        let name = values.volumeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
        let identity = values.volumeUUIDString.map { "uuid:\($0.lowercased())" }
            ?? "path:\(mountPath)"

        return VolumeSnapshot(
            id: identity,
            name: displayName,
            mountPath: mountPath,
            totalCapacity: total,
            availableCapacity: clampedAvailable,
            filesystem: values.volumeLocalizedFormatDescription,
            isReadOnly: values.volumeIsReadOnly,
            isLocal: values.volumeIsLocal,
            isInternal: values.volumeIsInternal,
            isRemovable: values.volumeIsRemovable,
            isPrimary: mountPath == "/"
        )
    }
}
