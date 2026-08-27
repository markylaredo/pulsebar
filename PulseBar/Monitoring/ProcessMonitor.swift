import Darwin
import Foundation

actor ProcessMonitor {
    private struct StableMetadata: Sendable {
        let name: String
        let architecture: String?
        let executablePath: String?
        let launchDate: Date
        let userID: uid_t
    }

    private var metadataCache: [ProcessIdentity: StableMetadata] = [:]
    private var cpuSamples: [ProcessIdentity: ProcessCPUSample] = [:]
    private let currentProcessID = getpid()
    private let currentUserID = getuid()

    func sample() -> [ProcessSnapshot] {
        let timestamp = DispatchTime.now().uptimeNanoseconds
        let processIDs = allProcessIDs()
        var activeIdentities = Set<ProcessIdentity>()
        var snapshots: [ProcessSnapshot] = []
        snapshots.reserveCapacity(processIDs.count)

        for processID in processIDs where processID > 0 {
            guard var taskInfo = taskAllInfo(for: processID) else { continue }

            let identity = ProcessIdentity(
                pid: processID,
                startTimeMicroseconds: taskInfo.pbsd.pbi_start_tvsec * 1_000_000
                    + taskInfo.pbsd.pbi_start_tvusec
            )
            activeIdentities.insert(identity)

            let metadata: StableMetadata
            if let cached = metadataCache[identity] {
                metadata = cached
            } else {
                metadata = readMetadata(processID: processID, bsdInfo: &taskInfo.pbsd)
                metadataCache[identity] = metadata
            }

            let cpuSample = ProcessCPUSample(
                totalTimeNanoseconds: taskInfo.ptinfo.pti_total_user + taskInfo.ptinfo.pti_total_system,
                timestampNanoseconds: timestamp
            )
            let cpuUsage = ProcessCPUCalculator.percentage(
                previous: cpuSamples[identity],
                current: cpuSample
            )
            cpuSamples[identity] = cpuSample

            snapshots.append(ProcessSnapshot(
                id: identity,
                name: metadata.name,
                cpuUsage: cpuUsage,
                residentMemory: taskInfo.ptinfo.pti_resident_size,
                threadCount: max(0, Int(taskInfo.ptinfo.pti_threadnum)),
                architecture: metadata.architecture,
                executablePath: metadata.executablePath,
                launchDate: metadata.launchDate,
                canTerminate: canTerminate(processID: processID, userID: metadata.userID)
            ))
        }

        metadataCache = metadataCache.filter { activeIdentities.contains($0.key) }
        cpuSamples = cpuSamples.filter { activeIdentities.contains($0.key) }
        return snapshots
    }

    func terminate(_ identity: ProcessIdentity, force: Bool) -> ProcessActionResult {
        guard identity.pid > 1, identity.pid != currentProcessID else {
            return .failure("PulseBar cannot terminate this process.")
        }
        guard let currentIdentity = currentIdentity(for: identity.pid), currentIdentity == identity else {
            return .failure("The process is no longer running.")
        }
        guard let metadata = metadataCache[identity], metadata.userID == currentUserID else {
            return .failure("This system process cannot be terminated by PulseBar.")
        }

        let signal = force ? SIGKILL : SIGTERM
        guard Darwin.kill(identity.pid, signal) == 0 else {
            if errno == ESRCH {
                return .failure("The process is no longer running.")
            }
            if errno == EPERM {
                return .failure("macOS does not allow PulseBar to terminate this process.")
            }
            return .failure(String(cString: strerror(errno)))
        }
        return .success
    }

    private func allProcessIDs() -> [pid_t] {
        let estimatedCount = max(Int(proc_listallpids(nil, 0)), 256)
        var processIDs = [pid_t](repeating: 0, count: estimatedCount + 128)
        let count = processIDs.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }
        return Array(processIDs.prefix(min(Int(count), processIDs.count)))
    }

    private func taskAllInfo(for processID: pid_t) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let expectedSize = Int32(MemoryLayout<proc_taskallinfo>.size)
        let actualSize = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pidinfo(processID, PROC_PIDTASKALLINFO, 0, pointer, expectedSize)
        }
        return actualSize == expectedSize ? info : nil
    }

    private func currentIdentity(for processID: pid_t) -> ProcessIdentity? {
        guard let info = taskAllInfo(for: processID) else { return nil }
        return ProcessIdentity(
            pid: processID,
            startTimeMicroseconds: info.pbsd.pbi_start_tvsec * 1_000_000
                + info.pbsd.pbi_start_tvusec
        )
    }

    private func readMetadata(processID: pid_t, bsdInfo: inout proc_bsdinfo) -> StableMetadata {
        let path = executablePath(for: processID)
        let registeredName = cString(from: &bsdInfo.pbi_name)
        let commandName = cString(from: &bsdInfo.pbi_comm)
        let pathName = path.map { URL(fileURLWithPath: $0).lastPathComponent }
        let name = [registeredName, pathName, commandName]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .first ?? "Process \(processID)"

        let startTime = TimeInterval(bsdInfo.pbi_start_tvsec)
            + TimeInterval(bsdInfo.pbi_start_tvusec) / 1_000_000
        return StableMetadata(
            name: name,
            architecture: nil,
            executablePath: path,
            launchDate: Date(timeIntervalSince1970: startTime),
            userID: bsdInfo.pbi_uid
        )
    }

    private func executablePath(for processID: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(processID, bytes.baseAddress, UInt32(bytes.count))
        }
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private func canTerminate(processID: pid_t, userID: uid_t) -> Bool {
        guard processID > 1, processID != currentProcessID, userID == currentUserID else {
            return false
        }
        return Darwin.kill(processID, 0) == 0
    }

    private func cString<T>(from value: inout T) -> String? {
        withUnsafeBytes(of: &value) { bytes in
            let characters = bytes.prefix { $0 != 0 }
            guard !characters.isEmpty else { return nil }
            return String(decoding: characters, as: UTF8.self)
        }
    }
}
