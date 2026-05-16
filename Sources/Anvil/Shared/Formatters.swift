import Foundation

enum Formatters {
    static func speed(_ bytesPerSecond: Int64) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return "\(byteCount(bytesPerSecond))/s"
    }

    static func byteCount(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "0 B" }
        let units: [(String, Double)] = [
            ("TB", 1_099_511_627_776),
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1024),
        ]
        for (unit, divisor) in units {
            if Double(bytes) >= divisor {
                let value = Double(bytes) / divisor
                if value >= 100 { return String(format: "%.0f %@", value, unit) }
                if value >= 10 { return String(format: "%.1f %@", value, unit) }
                return String(format: "%.2f %@", value, unit)
            }
        }
        return "\(bytes) B"
    }

    static func percent(_ progress: Double) -> String {
        let clamped = max(0, min(1, progress))
        return String(format: "%.1f%%", clamped * 100)
    }

    static func ratio(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        if value < 0 { return "0.00" }
        return String(format: "%.2f", value)
    }

    static func eta(_ seconds: Int64) -> String {
        guard seconds > 0, seconds < 8_640_000 else { return "∞" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if days >= 1 { return "\(days)d \(hours)h" }
        if hours >= 1 { return "\(hours)h \(minutes)m" }
        if minutes >= 1 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }

    static func duration(_ seconds: Int64) -> String {
        guard seconds > 0 else { return "—" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        if days >= 1 { return "\(days)d \(hours)h \(minutes)m" }
        if hours >= 1 { return "\(hours)h \(minutes)m" }
        if minutes >= 1 { return "\(minutes)m" }
        return "< 1m"
    }

    nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relativeDate(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func absoluteDate(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return absoluteFormatter.string(from: date)
    }
}
