import SwiftUI

struct PrinterDetailView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
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
            #if canImport(UIKit)
            viewModel.configureNFCScanner(services.nfcService)
            #endif
            viewModel.configureAutoPrint(services.autoPrintService)
            await viewModel.loadPrinter()

            // Handle NFC "mark ready" deep link
            if let pendingId = router.pendingNFCReadyPrinterId, pendingId == viewModel.printerId {
                viewModel.showNFCReadyConfirmation = true
                router.pendingNFCReadyPrinterId = nil
            }
        }
        .sheet(isPresented: $viewModel.showSpoolPicker) {
            SpoolPickerView { spool in
                Task { await viewModel.setActiveSpool(spool) }
            }
        }
        .sheet(isPresented: $viewModel.showScannedDataSheet) {
            if let data = viewModel.nfcScannedData {
                AddSpoolView(scannedData: data)
                    .onDisappear {
                        Task { await viewModel.loadPrinter() }
                    }
            }
        }
        .alert("Scan Error", isPresented: .constant(viewModel.nfcScanError != nil)) {
            Button("OK") { viewModel.nfcScanError = nil }
        } message: {
            if let error = viewModel.nfcScanError {
                Text(error)
            }
        }
        .alert("Mark Printer Ready?", isPresented: $viewModel.showNFCReadyConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Mark Ready") {
                Task { await viewModel.markPrinterReady() }
            }
        } message: {
            Text("Clear the bed and mark this printer as ready for the next print job?")
        }
    }

    // MARK: - Filament Section

    private func filamentSection(_ printer: Printer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filament")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if let spool = viewModel.effectiveSpoolInfo, spool.hasActiveSpool {
                    activeSpoolContent(spool)
                } else {
                    // No filament loaded
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "cylinder")
                                .font(.title2)
                                .foregroundStyle(Color.pfTextTertiary)
                            Text("No filament loaded")
                                .font(.subheadline)
                                .foregroundStyle(Color.pfTextSecondary)
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            Button {
                                viewModel.loadFilament()
                            } label: {
                                Label("Set", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.pfAccent)

                            NFCScanButton(action: {
                                viewModel.handleNFCScanToLoad()
                            })
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
    }

    @ViewBuilder
    private func activeSpoolContent(_ spool: PrinterSpoolInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: spool.colorHex ?? "#808080"))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.pfBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(spool.filamentName ?? spool.spoolName ?? "Unknown")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 6) {
                    if let material = spool.material {
                        Text(material)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pfBackgroundTertiary, in: Capsule())
                    }
                    if let vendor = spool.vendor {
                        Text(vendor)
                            .font(.caption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }

            Spacer()
        }

        if let remaining = spool.remainingWeightG {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(Color.pfTextSecondary)
                    Spacer()
                    Text("\(Int(remaining))g")
                        .font(.caption.weight(.medium))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pfBackgroundTertiary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pfAccent)
                            .frame(width: geo.size.width * filamentProgress(remaining: remaining), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }

        Divider()

        HStack(spacing: 12) {
            Button {
                viewModel.loadFilament()
            } label: {
                Label("Change", systemImage: "arrow.triangle.swap")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                Task { await viewModel.ejectFilament() }
            } label: {
                Label("Eject", systemImage: "eject.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.pfError)
        }
        .disabled(viewModel.isPerformingAction)

        NFCScanButton(action: {
            viewModel.handleNFCScanToLoad()
        }, compact: true)
    }

    /// Estimate progress assuming ~1000g full spool when no initial weight data is available
    private func filamentProgress(remaining: Double) -> CGFloat {
        let assumed = 1000.0
        return min(max(CGFloat(remaining / assumed), 0), 1)
    }

    // MARK: - Main Content

    private func printerContent(_ printer: Printer) -> some View {
        ScrollView {
            if sizeClass == .regular {
                iPadPrinterContent(printer)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(printer)
                    temperatureSection(printer)

                    if let jobName = printer.jobName,
                       let state = printer.state?.lowercased(),
                       state == "printing" || state == "paused" {
                        currentJobSection(jobName: jobName, progress: printer.progress)
                    }

                    cameraSection(printer)
                    filamentSection(printer)
                    AutoPrintSection(printerId: printer.id)

                    NavigationLink(value: AppDestination.predictiveInsights(printerId: printer.id)) {
                        HStack {
                            Label("Predictive Insights", systemImage: "gauge.with.dots.needle.33percent")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.pfBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if printer.isOnline {
                        actionSection(printer)
                    }
                }
                .padding()
            }
        }
    }

    private func iPadPrinterContent(_ printer: Printer) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Left column: header, temps, actions
            VStack(alignment: .leading, spacing: 20) {
                headerSection(printer)
                temperatureSection(printer)
                filamentSection(printer)
                AutoPrintSection(printerId: printer.id)

                NavigationLink(value: AppDestination.predictiveInsights(printerId: printer.id)) {
                    HStack {
                        Label("Predictive Insights", systemImage: "gauge.with.dots.needle.33percent")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.pfBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if printer.isOnline {
                    actionSection(printer)
                }
            }
            .frame(maxWidth: .infinity)

            // Right column: camera, current job
            VStack(alignment: .leading, spacing: 20) {
                cameraSection(printer)

                if let jobName = printer.jobName,
                   let state = printer.state?.lowercased(),
                   state == "printing" || state == "paused" {
                    currentJobSection(jobName: jobName, progress: printer.progress)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
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
        // Prefer printer temps (from CompletePrinterDto), fall back to statusDetail
        // (from /status endpoint). PrusaLink's PrinterDto omits temps but /status has them.
        let hotend = printer.hotendTemp ?? viewModel.statusDetail?.hotendTemp
        let hotendTgt = printer.hotendTarget ?? viewModel.statusDetail?.hotendTarget
        let bed = printer.bedTemp ?? viewModel.statusDetail?.bedTemp
        let bedTgt = printer.bedTarget ?? viewModel.statusDetail?.bedTarget

        return VStack(alignment: .leading, spacing: 12) {
            Text("Temperatures")
                .font(.headline)

            VStack(spacing: 8) {
                TemperatureView(
                    label: "Hotend",
                    current: hotend,
                    target: hotendTgt,
                    icon: "flame"
                )

                Divider()

                TemperatureView(
                    label: "Bed",
                    current: bed,
                    target: bedTgt,
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
                        viewModel.rotateCameraView()
                    } label: {
                        Image(systemName: "rotate.right")
                            .font(.subheadline)
                    }
                    .accessibilityLabel("Rotate camera view")
                    
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
                    .rotationEffect(.degrees(Double(viewModel.cameraRotation)))
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
                    .rotationEffect(.degrees(Double(viewModel.cameraRotation)))
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
                    .fullWidthActionButton()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(printer.inMaintenance ? "Exit maintenance mode" : "Enter maintenance mode")

                #if canImport(UIKit)
                // Write NFC printer tag
                Button {
                    viewModel.writeNFCPrinterTag()
                } label: {
                    Label("Write Tag", systemImage: "wave.3.right")
                        .fullWidthActionButton()
                }
                .buttonStyle(.bordered)
                .tint(Color.pfAccent)
                .accessibilityLabel("Write NFC printer identification tag")
                #endif

                // Emergency Stop (always available when online)
                Button(role: .destructive) {
                    viewModel.requestEmergencyStop()
                } label: {
                    Label("Emergency Stop", systemImage: "exclamationmark.octagon.fill")
                        .fullWidthActionButton(prominence: .prominent)
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
                .fullWidthActionButton()
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
}
