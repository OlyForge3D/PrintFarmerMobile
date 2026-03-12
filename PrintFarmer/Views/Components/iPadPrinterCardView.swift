import SwiftUI

/// Rich printer card for iPad — modeled after the web CompactPrinterCard.
/// Horizontal layout with state-tinted header, temps with targets, filament info,
/// and inline bed-clear banner for PendingReady state.
struct iPadPrinterCardView: View {
    let printer: Printer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color-tinted header
            headerSection

            // Body content
            VStack(alignment: .leading, spacing: 10) {
                // Temperature + Job row
                HStack(alignment: .top, spacing: 20) {
                    temperatureSection
                    Spacer()
                    jobSection
                }

                // Filament info row
                if let spool = printer.spoolInfo, spool.hasActiveSpool {
                    filamentRow(spool)
                }

                // Bed clear banner
                if isPendingReady {
                    bedClearBanner
                }
            }
            .padding(14)
        }
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusAccentColor.opacity(0.4), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

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

            // Status pill
            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.3), in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(headerGradient)
    }

    // MARK: - Temperatures

    private var temperatureSection: some View {
        HStack(spacing: 16) {
            if printer.isOnline {
                // Hotend
                if let temp = printer.hotendTemp {
                    Label {
                        temperatureText(current: temp, target: printer.hotendTarget)
                    } icon: {
                        NozzleIcon()
                            .fill(Color.pfNotHomed)
                            .frame(width: 16, height: 16)
                    }
                    .font(.subheadline)
                }

                // Bed
                if let temp = printer.bedTemp {
                    Label {
                        temperatureText(current: temp, target: printer.bedTarget)
                    } icon: {
                        RadiatorIcon()
                            .fill(Color.pfHomed)
                            .frame(width: 16, height: 16)
                    }
                    .font(.subheadline)
                }
            } else {
                Label("Offline", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func temperatureText(current: Double, target: Double?) -> some View {
        HStack(spacing: 2) {
            Text(String(format: "%.0f°", current))
                .monospacedDigit()
            if let target, target > 0 {
                Text("/")
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.0f°", target))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Job Progress

    @ViewBuilder
    private var jobSection: some View {
        if let jobName = printer.fileName ?? printer.jobName,
           let progress = printer.progress,
           let state = printer.state?.lowercased(),
           state == "printing" || state == "paused" {
            VStack(alignment: .trailing, spacing: 4) {
                Text(jobName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    PrintProgressBar(progress: progress, height: 8)
                        .frame(width: 120)

                    Text(progress.percentFormatted)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Filament Info

    private func filamentRow(_ spool: PrinterSpoolInfo) -> some View {
        HStack(spacing: 8) {
            // Spool color circle
            if let hex = spool.colorHex {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
            }

            // Material name
            if let material = spool.material {
                Text(material)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Filament name
            if let name = spool.filamentName {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Remaining weight
            if let weight = spool.remainingWeightG {
                Label {
                    Text(String(format: "%.0fg", weight))
                        .font(.caption.monospacedDigit())
                } icon: {
                    Image(systemName: "scalemass")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bed Clear Banner

    private var bedClearBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.pfWarning)

            Text("Bed clear required — confirm to continue")
                .font(.caption.weight(.medium))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.pfWarning.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Computed Properties

    private var isPendingReady: Bool {
        printer.state?.lowercased() == "pendingready"
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

    private var statusAccentColor: Color {
        if !printer.isOnline { return .pfTextTertiary }
        switch printer.state?.lowercased() {
        case "printing": return .pfSecondaryAccent
        case "paused": return .pfWarning
        case "error": return .pfError
        case "pendingready": return .pfWarning
        default: return .pfSuccess
        }
    }

    private var headerGradient: some ShapeStyle {
        LinearGradient(
            colors: [headerBaseColor, headerBaseColor.opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
        )
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
}
