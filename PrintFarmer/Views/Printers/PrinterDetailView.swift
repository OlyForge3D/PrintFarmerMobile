import SwiftUI

struct PrinterDetailView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: PrinterDetailViewModel

    init(printerId: UUID) {
        _viewModel = State(initialValue: PrinterDetailViewModel(printerId: printerId))
    }

    var body: some View {
        Group {
            if let printer = viewModel.printer {
                printerContent(printer)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadPrinter() }
                    }
                }
            } else {
                ProgressView("Loading printer…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.printer?.name ?? "Printer")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await viewModel.loadPrinter()
        }
        .alert(
            viewModel.pendingAction?.title ?? "Confirm",
            isPresented: $viewModel.showConfirmation,
            presenting: viewModel.pendingAction
        ) { _ in
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                Task { await viewModel.confirmAction() }
            }
        } message: { action in
            Text(action.message)
        }
        .alert("Action Failed", isPresented: .constant(viewModel.actionError != nil)) {
            Button("OK") { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError {
                Text(error)
            }
        }
        .task {
            viewModel.configure(printerService: services.printerService)
            await viewModel.loadPrinter()
        }
    }

    // MARK: - Main Content

    private func printerContent(_ printer: Printer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection(printer)

                // Temperatures
                temperatureSection(printer)

                // Current Job
                if let jobName = printer.jobName {
                    currentJobSection(jobName: jobName, progress: printer.progress)
                }

                // Camera Snapshot
                if let imageData = viewModel.snapshotData {
                    snapshotSection(data: imageData)
                }

                // Actions
                if printer.isOnline {
                    actionSection(printer)
                }
            }
            .padding()
        }
    }

    // MARK: - Header

    private func headerSection(_ printer: Printer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusBadge(printerState: printer.state, isOnline: printer.isOnline)

                if printer.inMaintenance {
                    StatusBadge(text: "Maintenance", color: .purple)
                }

                Spacer()

                if let model = printer.modelName {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let location = printer.location {
                Label(location.name, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let manufacturer = printer.manufacturerName {
                Label(manufacturer, systemImage: "building")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }

    // MARK: - Temperatures

    private func temperatureSection(_ printer: Printer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temperatures")
                .font(.headline)

            VStack(spacing: 8) {
                TemperatureView(
                    label: "Hotend",
                    current: printer.hotendTemp,
                    target: printer.hotendTarget,
                    icon: "flame"
                )

                Divider()

                TemperatureView(
                    label: "Bed",
                    current: printer.bedTemp,
                    target: printer.bedTarget,
                    icon: "square.stack.3d.up"
                )
            }
            .padding()
            .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.pfBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Current Job

    private func currentJobSection(jobName: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Job")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text(jobName)
                    .font(.subheadline.weight(.medium))

                if let progress {
                    VStack(alignment: .leading, spacing: 4) {
                        PrintProgressBar(progress: progress, height: 10)
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
    }

    // MARK: - Camera Snapshot

    private func snapshotSection(data: Data) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera")
                .font(.headline)

            #if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView {
                    Label("Snapshot Unavailable", systemImage: "camera.fill")
                }
                .frame(height: 200)
            }
            #else
            ContentUnavailableView {
                Label("Snapshot Unavailable", systemImage: "camera.fill")
            }
            .frame(height: 200)
            #endif
        }
    }

    // MARK: - Action Buttons

    private func actionSection(_ printer: Printer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            VStack(spacing: 10) {
                // Contextual actions based on state
                if viewModel.isPrinting {
                    HStack(spacing: 12) {
                        actionButton("Pause", icon: "pause.fill", color: .orange) {
                            await viewModel.pausePrinter()
                        }

                        actionButton("Cancel", icon: "xmark.circle.fill", color: .red) {
                            viewModel.requestCancel()
                        }
                    }
                }

                if viewModel.isPaused {
                    HStack(spacing: 12) {
                        actionButton("Resume", icon: "play.fill", color: .green) {
                            await viewModel.resumePrinter()
                        }

                        actionButton("Cancel", icon: "xmark.circle.fill", color: .red) {
                            viewModel.requestCancel()
                        }
                    }
                }

                if viewModel.isPrinting || viewModel.isPaused {
                    actionButton("Stop", icon: "stop.fill", color: .orange) {
                        await viewModel.stopPrinter()
                    }
                }

                // Maintenance toggle
                Button {
                    Task { await viewModel.toggleMaintenance() }
                } label: {
                    Label(
                        printer.inMaintenance ? "Exit Maintenance" : "Enter Maintenance",
                        systemImage: "wrench.and.screwdriver"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Emergency Stop (always available when online)
                Button(role: .destructive) {
                    viewModel.requestEmergencyStop()
                } label: {
                    Label("Emergency Stop", systemImage: "exclamationmark.octagon.fill")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .disabled(viewModel.isPerformingAction)
        }
    }

    private func actionButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
}
