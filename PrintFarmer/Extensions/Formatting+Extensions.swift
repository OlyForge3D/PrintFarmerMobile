import Foundation

extension Date {
    /// Formats the date for display using relative formatting when appropriate.
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

extension Double {
    /// Formats a temperature value with degree symbol (e.g., "215°C").
    var temperatureFormatted: String {
        String(format: "%.0f°C", self)
    }

    /// Formats a progress value as percentage (0.0–1.0 → "75%").
    var percentFormatted: String {
        String(format: "%.0f%%", self * 100)
    }
}

extension TimeInterval {
    /// Formats duration in human-readable form (e.g., "2h 15m").
    var durationFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
