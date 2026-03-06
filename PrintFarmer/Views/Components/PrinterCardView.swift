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
                            Image(systemName: "flame")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }

                    if let temp = printer.bedTemp {
                        Label {
                            Text(temp.temperatureFormatted)
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundStyle(.blue)
                        }
                        .font(.caption)
                    }
                }
            }

            // Job progress (if printing)
            if let jobName = printer.jobName, let progress = printer.progress {
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
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusAccentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusAccentColor: Color {
        if !printer.isOnline { return .gray }
        switch printer.state?.lowercased() {
        case "printing": return .blue
        case "paused": return .orange
        case "error": return .red
        default: return .green
        }
    }
}
