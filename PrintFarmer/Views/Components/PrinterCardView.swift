import SwiftUI

/// Compact card for a printer in list/grid views.
struct PrinterCardView: View {
    let printer: Printer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let location = printer.location {
                        Label(location.name, systemImage: "building.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                StatusBadge(printerState: printer.state, isOnline: printer.isOnline)
            }

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
            if let jobName = printer.jobName, let progress = printer.progress,
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
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusAccentColor.opacity(0.3), lineWidth: 1)
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
