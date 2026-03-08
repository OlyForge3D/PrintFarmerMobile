import SwiftUI

struct MaintenanceAlertRow: View {
    let alert: MaintenanceAlert
    var onAcknowledge: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                severityIcon
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.message)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

                    Label(alert.printerName, systemImage: "printer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(alert.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if alert.acknowledgedAt != nil {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Acknowledged")
                        .font(.caption)
                }
                .foregroundStyle(Color.pfSuccess)
            } else {
                HStack(spacing: 8) {
                    Button {
                        onAcknowledge()
                    } label: {
                        Label("Acknowledge", systemImage: "checkmark")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.pfAccent)

                    Button {
                        onDismiss()
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.pfTextSecondary)
                }
            }
        }
        .padding(12)
        .background(alertBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(alertBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Severity

    private var severityIcon: some View {
        Group {
            switch alert.severity.lowercased() {
            case "critical":
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.pfError)
            case "warning":
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.pfWarning)
            default:
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.pfAccent)
            }
        }
    }

    private var alertBackground: Color {
        switch alert.severity.lowercased() {
        case "critical": Color.pfError.opacity(0.05)
        case "warning": Color.pfWarning.opacity(0.05)
        default: Color.pfCard
        }
    }

    private var alertBorderColor: Color {
        switch alert.severity.lowercased() {
        case "critical": Color.pfError.opacity(0.3)
        case "warning": Color.pfWarning.opacity(0.3)
        default: Color.pfBorder
        }
    }
}
