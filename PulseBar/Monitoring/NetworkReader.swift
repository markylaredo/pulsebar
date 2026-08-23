import Darwin
import Foundation

struct NetworkCounters: Equatable, Sendable {
    var receivedBytes: UInt64 = 0
    var sentBytes: UInt64 = 0
    var receivedPackets: UInt64 = 0
    var sentPackets: UInt64 = 0
}

enum NetworkAccounting {
    static func calculate(
        previous: NetworkCounters?,
        current: NetworkCounters,
        elapsed: Double
    ) -> NetworkStats {
        guard let previous else {
            return NetworkStats(
                totalReceived: current.receivedBytes,
                totalTransmitted: current.sentBytes,
                totalPacketsReceived: current.receivedPackets,
                totalPacketsSent: current.sentPackets
            )
        }

        return NetworkStats(
            downloadRate: CounterMath.rate(previous: previous.receivedBytes, current: current.receivedBytes, elapsed: elapsed) ?? 0,
            uploadRate: CounterMath.rate(previous: previous.sentBytes, current: current.sentBytes, elapsed: elapsed) ?? 0,
            packetsReceivedRate: CounterMath.rate(previous: previous.receivedPackets, current: current.receivedPackets, elapsed: elapsed) ?? 0,
            packetsSentRate: CounterMath.rate(previous: previous.sentPackets, current: current.sentPackets, elapsed: elapsed) ?? 0,
            totalReceived: current.receivedBytes,
            totalTransmitted: current.sentBytes,
            totalPacketsReceived: current.receivedPackets,
            totalPacketsSent: current.sentPackets
        )
    }
}

struct NetworkReader {
    private var previous: (counters: NetworkCounters, time: ContinuousClock.Instant)?

    mutating func read(now: ContinuousClock.Instant = .now) -> NetworkStats {
        let counters = readCounters()
        defer { previous = (counters, now) }
        guard let previous else { return NetworkAccounting.calculate(previous: nil, current: counters, elapsed: 0) }
        let duration = previous.time.duration(to: now).components
        let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        return NetworkAccounting.calculate(previous: previous.counters, current: counters, elapsed: elapsed)
    }

    mutating func reset() { previous = nil }

    private func readCounters() -> NetworkCounters {
        var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return NetworkCounters() }

        var buffer = [UInt8](repeating: 0, count: length)
        let result = buffer.withUnsafeMutableBytes { bytes in
            sysctl(&mib, UInt32(mib.count), bytes.baseAddress, &length, nil, 0)
        }
        guard result == 0 else { return NetworkCounters() }

        return buffer.withUnsafeBytes { bytes in
            var counters = NetworkCounters()
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let message = bytes.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let messageLength = Int(message.ifm_msglen)
                guard messageLength > 0, offset + messageLength <= length else { break }

                if message.ifm_type == RTM_IFINFO2, messageLength >= MemoryLayout<if_msghdr2>.size {
                    let info = bytes.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if let name = interfaceName(index: info.ifm_index), isCounted(name: name, flags: info.ifm_flags) {
                        counters.receivedBytes &+= info.ifm_data.ifi_ibytes
                        counters.sentBytes &+= info.ifm_data.ifi_obytes
                        counters.receivedPackets &+= info.ifm_data.ifi_ipackets
                        counters.sentPackets &+= info.ifm_data.ifi_opackets
                    }
                }
                offset += messageLength
            }
            return counters
        }
    }

    private func interfaceName(index: UInt16) -> String? {
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        return name.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress,
                  if_indextoname(UInt32(index), baseAddress) != nil else { return nil }
            return String(cString: baseAddress)
        }
    }

    private func isCounted(name: String, flags: Int32) -> Bool {
        guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { return false }
        return !["awdl", "llw", "anpi", "gif", "stf", "ap"].contains { name.hasPrefix($0) }
    }
}
