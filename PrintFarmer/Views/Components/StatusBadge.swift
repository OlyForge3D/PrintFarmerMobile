import SwiftUI

/// Colored badge showing printer or job state.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Printer State Helpers

extension StatusBadge {
    /// Creates a badge from a printer's live state string.
    init(printerState: String?, isOnline: Bool) {
        if !isOnline {
            self.init(text: "Offline", color: .gray)
            return
        }
        guard let state = printerState?.lowercased() else {
            self.init(text: "Unknown", color: .gray)
            return
        }
        switch state {
        case "printing":
            self.init(text: "Printing", color: .blue)
        case "paused":
            self.init(text: "Paused", color: .orange)
        case "ready", "idle", "operational":
            self.init(text: "Idle", color: .green)
        case "error":
            self.init(text: "Error", color: .red)
        case "maintenance":
            self.init(text: "Maintenance", color: .purple)
        default:
            self.init(text: state.capitalized, color: .secondary)
        }
    }

    /// Creates a badge from a job status enum.
    init(jobStatus: PrintJobStatus) {
        switch jobStatus {
        case .queued:
            self.init(text: "Queued", color: .secondary)
        case .assigned:
            self.init(text: "Assigned", color: .cyan)
        case .starting:
            self.init(text: "Starting", color: .blue)
        case .printing:
            self.init(text: "Printing", color: .blue)
        case .paused:
            self.init(text: "Paused", color: .orange)
        case .completed:
            self.init(text: "Completed", color: .green)
        case .failed:
            self.init(text: "Failed", color: .red)
        case .cancelled:
            self.init(text: "Cancelled", color: .gray)
        }
    }
}
