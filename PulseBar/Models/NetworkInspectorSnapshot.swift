import Foundation

enum NetworkTransport: String, CaseIterable, Comparable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum NetworkConnectionState: String, Comparable, Sendable {
    case closed = "Closed"
    case listen = "Listening"
    case synSent = "SYN sent"
    case synReceived = "SYN received"
    case established = "Established"
    case closeWait = "Close wait"
    case finWait1 = "FIN wait 1"
    case closing = "Closing"
    case lastAck = "Last ACK"
    case finWait2 = "FIN wait 2"
    case timeWait = "Time wait"
    case reserved = "Reserved"
    case unknown = "Unknown"

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct NetworkEndpoint: Hashable, Sendable {
    let address: String
    let port: UInt16

    var displayName: String {
        let host = address.isEmpty || isUnspecified ? "*" : address
        guard port > 0 else { return host }
        return host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }

    var isUnspecified: Bool {
        address == "0.0.0.0" || address == "::" || address == "*"
    }
}

struct NetworkConnectionID: Hashable, Sendable {
    let pid: pid_t
    let socketHandle: UInt64
    let transport: NetworkTransport
    let local: NetworkEndpoint
    let remote: NetworkEndpoint?
}

struct NetworkConnectionSnapshot: Identifiable, Equatable, Sendable {
    let id: NetworkConnectionID
    let processIdentity: ProcessIdentity
    let processName: String
    let executablePath: String?
    let transport: NetworkTransport
    let local: NetworkEndpoint
    let remote: NetworkEndpoint?
    let state: NetworkConnectionState?
    let interfaceName: String?

    var pid: pid_t { id.pid }
    var sortName: String { processName.localizedLowercase }
    var protocolName: String { transport.rawValue }
    var localDisplayName: String { local.displayName }
    var remoteDisplayName: String { remote?.displayName ?? "—" }
    var localPort: Int { Int(local.port) }
    var remotePort: Int { Int(remote?.port ?? 0) }
    var stateName: String { state?.rawValue ?? (isListening ? "Bound" : "—") }

    var isListening: Bool {
        state == .listen || (transport == .udp && local.port > 0 && remote == nil)
    }

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        return processName.localizedCaseInsensitiveContains(normalized)
            || String(pid).contains(normalized)
            || local.displayName.localizedCaseInsensitiveContains(normalized)
            || (remote?.displayName.localizedCaseInsensitiveContains(normalized) ?? false)
            || String(local.port).contains(normalized)
            || (remote.map { String($0.port).contains(normalized) } ?? false)
    }
}

enum NetworkInterfaceKind: String, Comparable, Sendable {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case tunnel = "VPN / Tunnel"
    case loopback = "Loopback"
    case other = "Other"

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct NetworkInterfaceSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let kind: NetworkInterfaceKind
    let ipv4Addresses: [String]
    let ipv6Addresses: [String]
    let macAddress: String?
    let isUp: Bool
    let isRunning: Bool
    let isPrimary: Bool

    var name: String { id }
    var isActive: Bool { isUp && (isRunning || kind == .loopback) }
    var primaryAddress: String? { ipv4Addresses.first ?? ipv6Addresses.first }
    var isSystemRelevant: Bool {
        if isPrimary { return true }
        guard kind != .loopback, kind != .other else { return false }
        return !ipv4Addresses.isEmpty
            || ipv6Addresses.contains { !$0.lowercased().hasPrefix("fe80:") }
    }
    var status: String {
        if isPrimary && isActive { return "Primary" }
        return isActive ? "Active" : "Inactive"
    }
}

struct NetworkInspectorSnapshot: Equatable, Sendable {
    let connections: [NetworkConnectionSnapshot]
    let interfaces: [NetworkInterfaceSnapshot]
}

enum NetworkConnectionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case tcp = "TCP"
    case udp = "UDP"
    case listening = "Listening"
    case established = "Established"

    var id: Self { self }

    func includes(_ connection: NetworkConnectionSnapshot) -> Bool {
        switch self {
        case .all: true
        case .tcp: connection.transport == .tcp
        case .udp: connection.transport == .udp
        case .listening: connection.isListening
        case .established: connection.state == .established
        }
    }
}
