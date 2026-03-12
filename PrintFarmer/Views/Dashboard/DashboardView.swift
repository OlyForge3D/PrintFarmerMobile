import SwiftUI

struct DashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = DashboardViewModel()
    @State private var currentPage = 0

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.dashboardPath) {
            Group {
                if viewModel.isLoading && viewModel.printers.isEmpty {
                    loadingState
                } else if let error = viewModel.errorMessage, viewModel.printers.isEmpty {
                    errorState(error)
                } else if viewModel.printers.isEmpty {
                    // Empty fleet state
                    EmptyStateView(
                        icon: "printer",
                        title: "No Printers",
                        message: "No printers are registered. Add printers in PrintFarmer to see your fleet here."
                    )
                } else {
                    // iPhone: swipeable pages
                    if sizeClass == .compact {
                        VStack(spacing: 0) {
                            // Maintenance alerts banner (pinned)
                            if viewModel.hasMaintenanceAlerts {
                                maintenanceAlert
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                            }
                            
                            TabView(selection: $currentPage) {
                                OverviewPage()
                                    .tag(0)
                                ActivePage()
                                    .tag(1)
                                QueuePage()
                                    .tag(2)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            
                            PageIndicator(currentPage: $currentPage, pageCount: 3, labels: ["Overview", "Active", "Queue"])
                                .padding(.bottom, 8)
                        }
                    } else {
                        // iPad: keep existing ScrollView layout
                        iPadContent
                    }
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.loadDashboard()
            }
            .navigationDestination(for: AppDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .task {
            viewModel.configure(
                printerService: services.printerService,
                jobService: services.jobService,
                statisticsService: services.statisticsService,
                jobAnalyticsService: services.jobAnalyticsService
            )
            viewModel.configureSignalR(services.signalRService)
            await viewModel.loadDashboard()
        }
    }
    
    // MARK: - iPhone Pages
    
    @ViewBuilder
    private func OverviewPage() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summarySection
                
                if let stats = viewModel.queueStats {
                    queueHealthSection(stats: stats)
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }
    
    @ViewBuilder
    private func ActivePage() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                activeJobsSection
                
                if !viewModel.activePrintingPrinters.isEmpty {
                    activePrintETAsSection
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }
    
    @ViewBuilder
    private func QueuePage() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !viewModel.upcomingJobs.isEmpty {
                    upNextSection
                }
                
                if !viewModel.modelStats.isEmpty {
                    modelBreakdownSection
                }
                
                dispatchLink
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }
    
    // MARK: - iPad Content
    
    private var iPadContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Maintenance alerts banner
                if viewModel.hasMaintenanceAlerts {
                    maintenanceAlert
                }
                
                // Fleet summary cards
                summarySection
                
                // iPad: 2-column layout for active jobs + dispatch
                HStack(alignment: .top, spacing: 16) {
                    activeJobsSection
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 16) {
                        dispatchLink
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Farm Status sections
                farmStatusSections
            }
            .padding()
        }
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        let columnCount = sizeClass == .regular ? 6 : 3
        let columns = Array(repeating: GridItem(.flexible()), count: columnCount)
        let isIPad = sizeClass == .regular

        return VStack(alignment: .leading, spacing: 12) {
            Text("Fleet Overview")
                .font(.title2.bold())

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryCard(title: "Total", count: viewModel.printers.count, icon: "printer", color: .pfTextPrimary, isLarge: isIPad)
                SummaryCard(title: "Online", count: viewModel.onlineCount, icon: "wifi", color: .pfSuccess, isLarge: isIPad)
                SummaryCard(title: "Printing", count: viewModel.printingCount, icon: "printer.fill", color: .pfSecondaryAccent, isLarge: isIPad)
                SummaryCard(title: "Paused", count: viewModel.pausedCount, icon: "pause.circle", color: .pfWarning, isLarge: isIPad)
                SummaryCard(title: "Offline", count: viewModel.offlineCount, icon: "wifi.slash", color: .pfTextTertiary, isLarge: isIPad)
                SummaryCard(title: "Error", count: viewModel.errorCount, icon: "exclamationmark.triangle", color: .pfError, isLarge: isIPad)
            }
        }
    }

    // MARK: - Active Jobs (printers currently printing)

    private var activeJobsSection: some View {
        let activeStates: Set<String> = ["printing", "paused", "pendingready"]
        let printingPrinters = viewModel.printers.filter { printer in
            guard let state = printer.state?.lowercased() else { return false }
            return activeStates.contains(state)
        }
        .sorted { sortPriority($0) < sortPriority($1) }
        let topPrinters = Array(printingPrinters.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Jobs")
                    .font(.title2.bold())

                if viewModel.activeJobCount > 0 {
                    Text("\(viewModel.activeJobCount)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pfAccent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.pfAccent)
                }

                Spacer()

                if !topPrinters.isEmpty {
                    Button {
                        router.selectedTab = .jobs
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                    }
                }
            }

            if topPrinters.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No active jobs")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else if sizeClass == .regular {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(topPrinters) { printer in
                        NavigationLink(value: AppDestination.printerDetail(id: printer.id)) {
                            ActiveJobRow(printer: printer)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                ForEach(topPrinters) { printer in
                    NavigationLink(value: AppDestination.printerDetail(id: printer.id)) {
                        ActiveJobRow(printer: printer)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Queue depth summary
            if viewModel.queuedJobCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(viewModel.queuedJobCount) job(s) queued across fleet")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Farm Status Sections

    private var farmStatusSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Queue Health
            if let stats = viewModel.queueStats {
                queueHealthSection(stats: stats)
            }

            // Model breakdown + Active ETAs in 2-column on iPad
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    if !viewModel.modelStats.isEmpty {
                        modelBreakdownSection
                            .frame(maxWidth: .infinity)
                    }
                    if !viewModel.activePrintingPrinters.isEmpty {
                        activePrintETAsSection
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                if !viewModel.modelStats.isEmpty {
                    modelBreakdownSection
                }
                if !viewModel.activePrintingPrinters.isEmpty {
                    activePrintETAsSection
                }
            }

            // Up Next
            if !viewModel.upcomingJobs.isEmpty {
                upNextSection
            }
        }
    }

    private func queueHealthSection(stats: QueueStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Queue Health")
                .font(.title2.bold())

            let columns = sizeClass == .regular
                ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: 12) {
                queueStatCard(title: "Queued", count: stats.totalQueued, icon: "tray.full", color: .pfSecondaryAccent)
                queueStatCard(title: "Printing", count: stats.totalPrinting, icon: "printer.fill", color: .pfAccent)
                queueStatCard(title: "Paused", count: stats.totalPaused, icon: "pause.circle", color: .pfWarning)
                queueStatCard(title: "Avg Wait", count: stats.averageWaitTimeMinutes, icon: "clock", color: .pfSuccess, suffix: "m")
            }
        }
    }

    private func queueStatCard(title: String, count: Int, icon: String, color: Color, suffix: String = "") -> some View {
        VStack(spacing: sizeClass == .regular ? 8 : 6) {
            Image(systemName: icon)
                .font(sizeClass == .regular ? .title3 : .body)
                .foregroundStyle(color)

            HStack(spacing: 0) {
                Text("\(count)")
                    .font(sizeClass == .regular ? .title2.bold().monospacedDigit() : .title3.bold().monospacedDigit())
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(sizeClass == .regular ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(title)
                .font(sizeClass == .regular ? .caption : .caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, sizeClass == .regular ? 16 : 12)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }

    private var modelBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Printer Model")
                .font(.title2.bold())

            VStack(spacing: 8) {
                ForEach(viewModel.modelStats, id: \.modelName) { stat in
                    modelStatRow(stat: stat)
                }
            }
        }
    }

    private func modelStatRow(stat: QueuePrinterModelStats) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.modelName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if stat.currentlyPrinting > 0 {
                    Text("\(stat.currentlyPrinting) printing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.totalQueued)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Color.pfAccent)
                Text("queued")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }

    private var activePrintETAsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Print ETAs")
                .font(.title2.bold())

            VStack(spacing: 8) {
                ForEach(Array(viewModel.activePrintingPrinters.prefix(5)), id: \.id) { printer in
                    activePrintRow(printer: printer)
                }
            }
        }
    }

    private func activePrintRow(printer: Printer) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(printer.fileName ?? printer.jobName ?? "Unknown Job")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Label(printer.name, systemImage: "printer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let progress = printer.progress, progress > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(Color.pfAccent)
                    Text("printing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Up Next")
                .font(.title2.bold())

            VStack(spacing: 8) {
                ForEach(Array(viewModel.upcomingJobs.prefix(5)), id: \.job.id) { jobMeta in
                    upNextRow(jobMeta: jobMeta)
                }
            }
        }
    }

    private func upNextRow(jobMeta: QueuedJobWithMeta) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(jobMeta.job.fileName ?? jobMeta.job.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let printerName = jobMeta.assignedPrinter?.name {
                    Label(printerName, systemImage: "printer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let model = jobMeta.job.printerModel {
                    Label("Any \(model)", systemImage: "printer")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("#\(jobMeta.job.queuePosition)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.pfTextSecondary)
                if let eta = jobMeta.estimatedStartTime {
                    Text(eta.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }

    // MARK: - Dispatch Link

    private var dispatchLink: some View {
        NavigationLink(value: AppDestination.dispatchDashboard) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title3)
                    .foregroundStyle(Color.pfAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dispatch Dashboard")
                        .font(.subheadline.weight(.medium))
                    Text("View queue status and dispatch history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.pfBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Maintenance Alert

    private var maintenanceAlert: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundStyle(Color.pfWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.maintenanceCount) printer(s) in maintenance")
                    .font(.subheadline.weight(.medium))
                Text(viewModel.printersInMaintenance.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.pfWarning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 100)
            ProgressView("Loading dashboard…")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.loadDashboard() }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sortPriority(_ printer: Printer) -> Int {
        guard printer.isOnline else { return 100 }
        switch printer.state?.lowercased() {
        case "pendingready": return 0
        case "printing": return 1
        case "ready", "idle": return 2
        default: return 3
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    var isLarge: Bool = false

    var body: some View {
        VStack(spacing: isLarge ? 10 : 6) {
            Image(systemName: icon)
                .font(isLarge ? .title2 : .title3)
                .foregroundStyle(color)

            Text("\(count)")
                .font(isLarge ? .title.bold().monospacedDigit() : .title2.bold().monospacedDigit())

            Text(title)
                .font(isLarge ? .subheadline : .caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isLarge ? 20 : 14)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }
}

// MARK: - Navigation Helper

@MainActor @ViewBuilder
func destinationView(for destination: AppDestination) -> some View {
    switch destination {
    case .printerDetail(let id):
        PrinterDetailView(printerId: id)
    case .jobDetail(let id):
        JobDetailView(jobId: id)
    case .locationDetail:
        ContentUnavailableView {
            Label("Coming Soon", systemImage: "map")
        } description: {
            Text("Location details will be available in a future update.")
        }
    case .createJob:
        ContentUnavailableView {
            Label("Coming Soon", systemImage: "plus.circle")
        } description: {
            Text("Job creation will be available in a future update.")
        }
    case .createPrinter:
        ContentUnavailableView {
            Label("Coming Soon", systemImage: "printer.fill.and.paper")
        } description: {
            Text("Printer setup will be available in a future update.")
        }
    case .maintenanceAnalytics:
        MaintenanceAnalyticsView()
    case .uptimeReliability:
        UptimeView()
    case .predictiveInsights(let printerId):
        PredictiveInsightsView(printerId: printerId)
    case .jobHistory:
        JobHistoryView()
    case .jobTimeline:
        JobTimelineView()
    case .dispatchDashboard:
        DispatchDashboardView()
    }
}

// MARK: - Active Job Row (printer with running job)

private struct ActiveJobRow: View {
    let printer: Printer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.fileName ?? printer.jobName ?? "Unknown Job")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Label(printer.name, systemImage: "printer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(printerState: printer.state, isOnline: printer.isOnline)
            }

            if let progress = printer.progress {
                PrintProgressBar(progress: progress, height: 6)
            }
        }
        .padding(12)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }
}
