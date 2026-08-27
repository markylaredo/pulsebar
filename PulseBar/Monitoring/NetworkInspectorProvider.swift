import Darwin
import Foundation
import SystemConfiguration

actor NetworkInspectorProvider {
    private struct ProcessMetadata: Sendable {
        let identity: ProcessIdentity
        let name: String
        let executablePath: String?
    }

    private struct InterfaceBuilder {
        let name: String
        var displayName: String
        var kind: NetworkInterfaceKind
        var ipv4Addresses: Set<String> = []
        var ipv6Addresses: Set<String> = []
        var macAddress: String?
        var isUp = false
        var isRunning = false
    }

    private var metadataCache: [ProcessIdentity: ProcessMetadata] = [:]

    func snapshot() -> NetworkInspectorSnapshot {
        let interfaces = readInterfaces()
        let addressToInterface = interfaces.reduce(into: [String: String]()) { result, interface in
            for address in interface.ipv4Addresses + interface.ipv6Addresses where result[address] == nil {
                result[address] = interface.name
            }
        }
        let connections = readConnections(addressToInterface: addressToInterface)
        let activeIdentities = Set(connections.map(\.processIdentity))
        metadataCache = metadataCache.filter { activeIdentities.contains($0.key) }
        return NetworkInspectorSnapshot(connections: connections, interfaces: interfaces)
    }

    private func readConnections(addressToInterface: [String: String]) -> [NetworkConnectionSnapshot] {
        var connections: [NetworkConnectionID: NetworkConnectionSnapshot] = [:]

        for processID in allProcessIDs() where processID > 0 {
            let socketDescriptors = fileDescriptors(for: processID).filter {
                $0.proc_fdtype == PROX_FDTYPE_SOCKET
            }
            guard !socketDescriptors.isEmpty else { continue }
            let metadata = processMetadata(for: processID)
            for descriptor in socketDescriptors {
                guard let socket = socketInfo(processID: processID, descriptor: descriptor),
                      let connection = connectionSnapshot(
                        socket: socket,
                        metadata: metadata,
                        addressToInterface: addressToInterface
                      ) else { continue }
                connections[connection.id] = connection
            }
        }

        return connections.values.sorted { lhs, rhs in
            if lhs.sortName != rhs.sortName { return lhs.sortName < rhs.sortName }
            if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
            if lhs.transport != rhs.transport { return lhs.transport < rhs.transport }
            if lhs.localPort != rhs.localPort { return lhs.localPort < rhs.localPort }
            if lhs.remotePort != rhs.remotePort { return lhs.remotePort < rhs.remotePort }
            return lhs.id.socketHandle < rhs.id.socketHandle
        }
    }

    private func connectionSnapshot(
        socket: socket_fdinfo,
        metadata: ProcessMetadata,
        addressToInterface: [String: String]
    ) -> NetworkConnectionSnapshot? {
        let socketInfo = socket.psi
        let transport: NetworkTransport
        let internetInfo: in_sockinfo
        let state: NetworkConnectionState?

        switch socketInfo.soi_protocol {
        case IPPROTO_TCP:
            guard socketInfo.soi_kind == SOCKINFO_TCP else { return nil }
            transport = .tcp
            let tcp = socketInfo.soi_proto.pri_tcp
            internetInfo = tcp.tcpsi_ini
            state = tcpState(tcp.tcpsi_state)
        case IPPROTO_UDP:
            guard socketInfo.soi_kind == SOCKINFO_IN else { return nil }
            transport = .udp
            internetInfo = socketInfo.soi_proto.pri_in
            state = nil
        default:
            return nil
        }

        guard let localAddress = numericAddress(internetInfo, local: true),
              let foreignAddress = numericAddress(internetInfo, local: false) else { return nil }

        let local = NetworkEndpoint(
            address: localAddress,
            port: hostPort(internetInfo.insi_lport)
        )
        let foreign = NetworkEndpoint(
            address: foreignAddress,
            port: hostPort(internetInfo.insi_fport)
        )
        let remote = foreign.isUnspecified && foreign.port == 0 ? nil : foreign
        let normalizedLocalAddress = localAddress.split(separator: "%", maxSplits: 1).first.map(String.init)
            ?? localAddress
        let interfaceName = addressToInterface[normalizedLocalAddress]
        let id = NetworkConnectionID(
            pid: metadata.identity.pid,
            socketHandle: socketInfo.soi_so,
            transport: transport,
            local: local,
            remote: remote
        )

        return NetworkConnectionSnapshot(
            id: id,
            processIdentity: metadata.identity,
            processName: metadata.name,
            executablePath: metadata.executablePath,
            transport: transport,
            local: local,
            remote: remote,
            state: state,
            interfaceName: interfaceName
        )
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

    private func fileDescriptors(for processID: pid_t) -> [proc_fdinfo] {
        let requiredBytes = proc_pidinfo(processID, PROC_PIDLISTFDS, 0, nil, 0)
        guard requiredBytes > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](
            repeating: proc_fdinfo(),
            count: Int(requiredBytes) / stride + 16
        )
        let actualBytes = descriptors.withUnsafeMutableBytes { bytes in
            proc_pidinfo(
                processID,
                PROC_PIDLISTFDS,
                0,
                bytes.baseAddress,
                Int32(bytes.count)
            )
        }
        guard actualBytes > 0 else { return [] }
        return Array(descriptors.prefix(min(Int(actualBytes) / stride, descriptors.count)))
    }

    private func socketInfo(processID: pid_t, descriptor: proc_fdinfo) -> socket_fdinfo? {
        var socket = socket_fdinfo()
        let expectedSize = Int32(MemoryLayout<socket_fdinfo>.size)
        let actualSize = withUnsafeMutablePointer(to: &socket) { pointer in
            proc_pidfdinfo(
                processID,
                descriptor.proc_fd,
                PROC_PIDFDSOCKETINFO,
                pointer,
                expectedSize
            )
        }
        return actualSize == expectedSize ? socket : nil
    }

    private func processMetadata(for processID: pid_t) -> ProcessMetadata {
        guard var bsdInfo = bsdInfo(for: processID) else {
            return ProcessMetadata(
                identity: ProcessIdentity(pid: processID, startTimeMicroseconds: 0),
                name: "Unknown Process",
                executablePath: nil
            )
        }
        let identity = ProcessIdentity(
            pid: processID,
            startTimeMicroseconds: bsdInfo.pbi_start_tvsec * 1_000_000
                + bsdInfo.pbi_start_tvusec
        )
        if let cached = metadataCache[identity] { return cached }

        let path = executablePath(for: processID)
        let registeredName = cString(from: &bsdInfo.pbi_name)
        let commandName = cString(from: &bsdInfo.pbi_comm)
        let pathName = path.map { URL(fileURLWithPath: $0).lastPathComponent }
        let name = [registeredName, pathName, commandName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .first ?? "Unknown Process"
        let metadata = ProcessMetadata(identity: identity, name: name, executablePath: path)
        metadataCache[identity] = metadata
        return metadata
    }

    private func bsdInfo(for processID: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let expectedSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        let actualSize = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pidinfo(processID, PROC_PIDTBSDINFO, 0, pointer, expectedSize)
        }
        return actualSize == expectedSize ? info : nil
    }

    private func executablePath(for processID: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(processID, bytes.baseAddress, UInt32(bytes.count))
        }
        return length > 0 ? String(cString: buffer) : nil
    }

    private func readInterfaces() -> [NetworkInterfaceSnapshot] {
        let primary = primaryInterfaceName()
        let metadata = interfaceMetadata()
        var builders: [String: InterfaceBuilder] = [:]
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else { return [] }
        defer { freeifaddrs(firstAddress) }

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let pointer = current {
            let entry = pointer.pointee
            let name = String(cString: entry.ifa_name)
            let flags = entry.ifa_flags
            let typeMetadata = metadata[name]
            var builder = builders[name] ?? InterfaceBuilder(
                name: name,
                displayName: typeMetadata?.displayName ?? name,
                kind: interfaceKind(name: name, flags: flags, systemType: typeMetadata?.type)
            )
            builder.isUp = builder.isUp || flags & UInt32(IFF_UP) != 0
            builder.isRunning = builder.isRunning || flags & UInt32(IFF_RUNNING) != 0

            if let address = entry.ifa_addr {
                switch Int32(address.pointee.sa_family) {
                case AF_INET:
                    if let value = numericAddress(address) { builder.ipv4Addresses.insert(value) }
                case AF_INET6:
                    if let value = numericAddress(address) { builder.ipv6Addresses.insert(value) }
                case AF_LINK:
                    builder.macAddress = builder.macAddress ?? macAddress(address)
                default:
                    break
                }
            }
            builders[name] = builder
            current = entry.ifa_next
        }

        return builders.values.map { builder in
            NetworkInterfaceSnapshot(
                id: builder.name,
                displayName: builder.displayName,
                kind: builder.kind,
                ipv4Addresses: builder.ipv4Addresses.sorted(),
                ipv6Addresses: builder.ipv6Addresses.sorted(),
                macAddress: builder.macAddress,
                isUp: builder.isUp,
                isRunning: builder.isRunning,
                isPrimary: builder.name == primary
            )
        }
        .filter { $0.isActive || $0.primaryAddress != nil }
        .sorted { lhs, rhs in
            if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func interfaceMetadata() -> [String: (displayName: String, type: String)] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        return interfaces.reduce(into: [:]) { result, interface in
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let type = SCNetworkInterfaceGetInterfaceType(interface) as String?,
                  result[name] == nil else { return }
            let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? ?? name
            result[name] = (displayName, type)
        }
    }

    private func primaryInterfaceName() -> String? {
        guard let value = SCDynamicStoreCopyValue(
            nil,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any] else { return nil }
        return value[kSCDynamicStorePropNetPrimaryInterface as String] as? String
    }

    private func interfaceKind(name: String, flags: UInt32, systemType: String?) -> NetworkInterfaceKind {
        if flags & UInt32(IFF_LOOPBACK) != 0 { return .loopback }
        if systemType == (kSCNetworkInterfaceTypeIEEE80211 as String) { return .wifi }
        if systemType == (kSCNetworkInterfaceTypeEthernet as String) { return .ethernet }
        if systemType == (kSCNetworkInterfaceTypeIPSec as String)
            || systemType == (kSCNetworkInterfaceTypePPP as String) { return .tunnel }
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") { return .tunnel }
        return .other
    }

    private func numericAddress(_ info: in_sockinfo, local: Bool) -> String? {
        let flags = Int32(info.insi_vflag)
        if flags & INI_IPV6 != 0 {
            var address = local ? info.insi_laddr.ina_6 : info.insi_faddr.ina_6
            return stringAddress(family: AF_INET6, address: &address)
        }
        if flags & INI_IPV4 != 0 {
            var address = local ? info.insi_laddr.ina_46.i46a_addr4 : info.insi_faddr.ina_46.i46a_addr4
            return stringAddress(family: AF_INET, address: &address)
        }
        return nil
    }

    private func stringAddress(family: Int32, address: inout in_addr) -> String? {
        withUnsafePointer(to: &address) { pointer in
            stringAddress(family: family, address: UnsafeRawPointer(pointer))
        }
    }

    private func stringAddress(family: Int32, address: inout in6_addr) -> String? {
        withUnsafePointer(to: &address) { pointer in
            stringAddress(family: family, address: UnsafeRawPointer(pointer))
        }
    }

    private func stringAddress(family: Int32, address: UnsafeRawPointer) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        return buffer.withUnsafeMutableBufferPointer { output in
            guard let baseAddress = output.baseAddress,
                  inet_ntop(family, address, baseAddress, socklen_t(output.count)) != nil else { return nil }
            return String(cString: baseAddress)
        }
    }

    private func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        return result == 0 ? String(cString: host) : nil
    }

    private func macAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        let link = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_dl.self).pointee
        let length = Int(link.sdl_alen)
        guard length > 0, let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data) else {
            return nil
        }
        return withUnsafePointer(to: link) { pointer in
            let bytes = UnsafeRawPointer(pointer)
                .advanced(by: dataOffset + Int(link.sdl_nlen))
                .assumingMemoryBound(to: UInt8.self)
            return (0..<length).map { String(format: "%02x", bytes[$0]) }.joined(separator: ":")
        }
    }

    private func hostPort(_ networkPort: Int32) -> UInt16 {
        UInt16(bigEndian: UInt16(truncatingIfNeeded: networkPort))
    }

    private func tcpState(_ state: Int32) -> NetworkConnectionState {
        switch state {
        case TSI_S_CLOSED: .closed
        case TSI_S_LISTEN: .listen
        case TSI_S_SYN_SENT: .synSent
        case TSI_S_SYN_RECEIVED: .synReceived
        case TSI_S_ESTABLISHED: .established
        case TSI_S__CLOSE_WAIT: .closeWait
        case TSI_S_FIN_WAIT_1: .finWait1
        case TSI_S_CLOSING: .closing
        case TSI_S_LAST_ACK: .lastAck
        case TSI_S_FIN_WAIT_2: .finWait2
        case TSI_S_TIME_WAIT: .timeWait
        case TSI_S_RESERVED: .reserved
        default: .unknown
        }
    }

    private func cString<T>(from value: inout T) -> String? {
        withUnsafeBytes(of: &value) { bytes in
            let characters = bytes.prefix { $0 != 0 }
            return characters.isEmpty ? nil : String(decoding: characters, as: UTF8.self)
        }
    }
}
