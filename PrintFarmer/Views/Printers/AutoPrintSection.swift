import SwiftUI

struct AutoPrintSection: View {
    let printerId: UUID
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = AutoPrintViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto-Print")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if viewModel.isLoading && viewModel.status == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if let error = viewModel.error, viewModel.status == nil {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.pfWarning)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Enable/disable toggle
                    Toggle(isOn: Binding(
                        get: { viewModel.isEnabled },
                        set: { _ in
                            Task { await viewModel.toggleEnabled(printerId: printerId) }
                        }
                    )) {
                        Label("Auto-Print Enabled", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                    }

                    if viewModel.isEnabled {
                        // Current state
                        HStack(spacing: 8) {
                            Image(systemName: stateIcon)
                                .foregroundStyle(stateColor)
                            Text(viewModel.currentState)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Filament check result
                        if let result = viewModel.readyResult {
                            filamentCheckResult(result)
                        }

                        // Action buttons
                        HStack(spacing: 8) {
                            Button {
                                Task { await viewModel.markReady(printerId: printerId) }
                            } label: {
                                Label("Next Job", systemImage: "play.fill")
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.pfAccent)

                            Button {
                                Task { await viewModel.skip(printerId: printerId) }
                            } label: {
                                Label("Skip", systemImage: "forward.fill")
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
            .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.pfBorder, lineWidth: 1)
            )
        }
        .task {
            viewModel.configure(autoPrintService: services.autoPrintService)
            await viewModel.loadStatus(printerId: printerId)
        }
    }

    // MARK: - Filament Check

    private func filamentCheckResult(_ result: AutoPrintReadyResult) -> some View {
        HStack(spacing: 8) {
            let filamentOk = result.filamentCheck?.sufficient ?? false

            Image(systemName: filamentOk ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(filamentOk ? Color.pfSuccess : Color.pfWarning)

            VStack(alignment: .leading, spacing: 1) {
                Text(filamentOk ? "Filament check passed" : "Filament check failed")
                    .font(.caption.weight(.medium))

                if let message = result.filamentCheck?.message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(
            ((result.filamentCheck?.sufficient ?? false) ? Color.pfSuccess : Color.pfWarning).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    // MARK: - Helpers

    private var stateIcon: String {
        switch viewModel.currentState.lowercased() {
        case "idle": return "moon"
        case "ready": return "checkmark.circle"
        case "printing": return "printer.fill"
        case "waiting": return "clock"
        default: return "questionmark.circle"
        }
    }

    private var stateColor: Color {
        switch viewModel.currentState.lowercased() {
        case "idle": return .pfTextTertiary
        case "ready": return .pfSuccess
        case "printing": return .pfAccent
        case "waiting": return .pfWarning
        default: return .pfTextSecondary
        }
    }
}
