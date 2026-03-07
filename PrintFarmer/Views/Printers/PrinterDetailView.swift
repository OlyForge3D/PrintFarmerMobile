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

                // Current Job (only when printing or paused)
                if let jobName = printer.jobName,
                   let state = printer.state?.lowercased(),
                   state == "printing" || state == "paused" {
                    currentJobSection(jobName: jobName, progress: printer.progress)
                }

                // Camera Snapshot
                cameraSection(printer)

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
                    StatusBadge(text: "Maintenance", color: .pfMaintenance)
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

    private func cameraSection(_ printer: Printer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Camera")
                    .font(.headline)

                Spacer()

                if viewModel.snapshotData != nil || printer.cameraSnapshotUrl != nil {
                    Button {
                        Task { await viewModel.refreshSnapshot() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .disabled(viewModel.isLoadingSnapshot)
                    .accessibilityLabel("Refresh camera snapshot")
                }
            }

            Group {
                if let data = viewModel.snapshotData {
                    snapshotImage(from: data)
                } else if let urlString = printer.cameraSnapshotUrl,
                          let url = URL(string: urlString) {
                    asyncSnapshotImage(url: url)
                } else {
                    noCameraPlaceholder()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.pfBorder, lineWidth: 1)
            )
        }
    }

    #if canImport(UIKit)
    private func snapshotImage(from data: Data) -> some View {
        Group {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                snapshotUnavailable()
            }
        }
    }
    #else
    private func snapshotImage(from data: Data) -> some View {
        snapshotUnavailable()
    }
    #endif

    private func asyncSnapshotImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            case .failure:
                snapshotUnavailable()
            case .empty:
                ProgressView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            @unknown default:
                EmptyView()
            }
        }
    }

    private func noCameraPlaceholder() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.title)
                .foregroundStyle(Color.pfTextTertiary)
            Text("No camera available")
                .font(.subheadline)
                .foregroundStyle(Color.pfTextSecondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private func snapshotUnavailable() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title)
                .foregroundStyle(Color.pfTextTertiary)
            Text("Snapshot unavailable")
                .font(.subheadline)
                .foregroundStyle(Color.pfTextSecondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
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
                        actionButton("Pause", icon: "pause.fill", color: .pfWarning) {
                            await viewModel.pausePrinter()
                        }

                        actionButton("Cancel", icon: "xmark.circle.fill", color: .pfError) {
                            viewModel.requestCancel()
                        }
                    }
                }

                if viewModel.isPaused {
                    HStack(spacing: 12) {
                        actionButton("Resume", icon: "play.fill", color: .pfSuccess) {
                            await viewModel.resumePrinter()
                        }

                        actionButton("Cancel", icon: "xmark.circle.fill", color: .pfError) {
                            viewModel.requestCancel()
                        }
                    }
                }

                if viewModel.isPrinting || viewModel.isPaused {
                    actionButton("Stop", icon: "stop.fill", color: .pfWarning) {
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
                .accessibilityLabel(printer.inMaintenance ? "Exit maintenance mode" : "Enter maintenance mode")

                // Emergency Stop (always available when online)
                Button(role: .destructive) {
                    viewModel.requestEmergencyStop()
                } label: {
                    Label("Emergency Stop", systemImage: "exclamationmark.octagon.fill")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pfError)
                .accessibilityLabel("Emergency stop printer")
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
