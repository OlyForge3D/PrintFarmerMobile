import SwiftUI

/// Compact card for a printer in list/grid views.
struct PrinterCardView: View {
    let printer: Printer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            // Body — always show all elements for consistent card sizing
            VStack(alignment: .leading, spacing: 10) {
                // Job info + progress (above temps, matching web UI order)
                VStack(alignment: .leading, spacing: 4) {
                    Text(printer.fileName ?? printer.jobName ?? "---")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    PrintProgressBar(progress: printer.progress ?? 0, height: 6)
                }

                // Temperature row — always visible with placeholders
                HStack(spacing: 16) {
                    Label {
                        temperatureText(current: printer.hotendTemp, target: printer.hotendTarget)
                    } icon: {
                        NozzleIcon()
                            .fill(hotendIconColor)
                            .frame(width: 14, height: 14)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Label {
                        temperatureText(current: printer.bedTemp, target: printer.bedTarget)
                    } icon: {
                        RadiatorIcon()
                            .fill(bedIconColor)
                            .frame(width: 14, height: 14)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        case "pendingready": return Color(hex: "#eab308")
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

    private func temperatureText(current: Double?, target: Double?) -> some View {
        HStack(spacing: 2) {
            Text(current.map { String(format: "%.0f°C", $0) } ?? "---°C")
                .monospacedDigit()
            if let target, target > 0 {
                Text("→")
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.0f°C", target))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hotendIconColor: Color {
        if let target = printer.hotendTarget, target > 0 {
            return .red
        } else {
            return .red.opacity(0.35)
        }
    }

    private var bedIconColor: Color {
        if let target = printer.bedTarget, target > 0 {
            return .blue
        } else {
            return .blue.opacity(0.35)
        }
    }
}
