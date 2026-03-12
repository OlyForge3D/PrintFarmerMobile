import SwiftUI

/// Compact card for a printer in list/grid views.
struct PrinterCardView: View {
    let printer: Printer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            // Body
            VStack(alignment: .leading, spacing: 10) {
                // Temperature row
                if printer.isOnline {
                    HStack(spacing: 16) {
                        if let temp = printer.hotendTemp {
                            Label {
                                Text(temp.temperatureFormatted)
                                    .monospacedDigit()
                            } icon: {
                                NozzleIcon()
                                    .fill(Color.pfNotHomed)
                                    .frame(width: 14, height: 14)
                            }
                            .font(.caption)
                        }

                        if let temp = printer.bedTemp {
                            Label {
                                Text(temp.temperatureFormatted)
                                    .monospacedDigit()
                            } icon: {
                                RadiatorIcon()
                                    .fill(Color.pfHomed)
                                    .frame(width: 14, height: 14)
                            }
                            .font(.caption)
                        }
                    }
                }

                // Job progress (only when actively printing or paused)
                if let jobName = printer.fileName ?? printer.jobName, let progress = printer.progress,
                   let state = printer.state?.lowercased(),
                   state == "printing" || state == "paused" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(jobName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        PrintProgressBar(progress: progress, height: 6)
                    }
                }
            }
            .padding(14)
        }
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusAccentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(printer.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let location = printer.location {
                    Label(location.name, systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(statusLabel)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.black.opacity(0.3), in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(headerGradient)
    }

    private var statusLabel: String {
        guard printer.isOnline else { return "Offline" }
        guard let state = printer.state else { return "Idle" }
        switch state.lowercased() {
        case "printing": return "Printing"
        case "paused": return "Paused"
        case "error": return "Error"
        case "pendingready": return "Bed Clear"
        case "idle", "ready": return "Ready"
        default: return state.capitalized
        }
    }

    private var headerBaseColor: Color {
        if !printer.isOnline { return Color(hex: "#4b5563") }
        switch printer.state?.lowercased() {
        case "printing": return Color(hex: "#1d4ed8")
        case "paused": return Color(hex: "#b45309")
        case "error": return Color(hex: "#dc2626")
        case "pendingready": return Color(hex: "#b45309")
        default: return Color(hex: "#059669")
        }
    }

    private var headerGradient: some ShapeStyle {
        LinearGradient(
            colors: [headerBaseColor, headerBaseColor.opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var statusAccentColor: Color {
        if !printer.isOnline { return .pfTextTertiary }
        switch printer.state?.lowercased() {
        case "printing": return .pfSecondaryAccent
        case "paused": return .pfWarning
        case "error": return .pfError
        default: return .pfSuccess
        }
    }
}
