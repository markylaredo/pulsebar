import Foundation

enum MetricFormatter {
    private static let byteUnits = ["B", "KB", "MB", "GB", "TB", "PB"]

    static func bytes(_ value: UInt64) -> String {
        scaled(Double(value), suffix: "")
    }

    static func memory(_ value: UInt64) -> String {
        let amount = Double(value)
        guard amount >= 1_024 else { return "\(value) B" }
        let exponent = min(Int(log(amount) / log(1_024)), byteUnits.count - 1)
        let scaled = amount / pow(1_024, Double(exponent))
        let formatted = exponent >= 3
            ? String(format: "%.2f", scaled)
            : number(scaled)
        return "\(formatted) \(byteUnits[exponent])"
    }

    static func rate(_ value: Double) -> String {
        scaled(max(0, value), suffix: "/s")
    }

    static func count(_ value: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func packetRate(_ value: Double) -> String {
        "\(count(UInt64(max(0, value).rounded()))) pkt/s"
    }

    static func compactRate(_ value: Double) -> String {
        let safe = max(0, value)
        guard safe >= 1_000 else { return "\(Int(safe))B" }
        let exponent = min(Int(log(safe) / log(1_000)), 4)
        let unit = ["", "K", "M", "G", "T"][exponent]
        let scaled = safe / pow(1_000, Double(exponent))
        return "\(number(scaled))\(unit)"
    }

    static func percentage(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds)) / 60
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func scaled(_ value: Double, suffix: String) -> String {
        guard value >= 1_000 else { return "\(Int(value)) B\(suffix)" }
        let exponent = min(Int(log(value) / log(1_000)), byteUnits.count - 1)
        let scaled = value / pow(1_000, Double(exponent))
        return "\(number(scaled)) \(byteUnits[exponent])\(suffix)"
    }

    private static func number(_ value: Double) -> String {
        if value >= 100 || value.rounded() == value { return String(format: "%.0f", value) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.1f", value)
    }
}
