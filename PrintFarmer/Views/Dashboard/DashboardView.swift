import SwiftUI

struct DashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.dashboardPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isLoading && viewModel.printers.isEmpty {
                        loadingState
                    } else if let error = viewModel.errorMessage, viewModel.printers.isEmpty {
                        errorState(error)
                    } else {
                        // Maintenance alerts banner
                        if viewModel.hasMaintenanceAlerts {
                            maintenanceAlert
                        }

                        // Fleet summary cards
                        summarySection

                        // Active jobs
                        activeJobsSection
                    }
                }
                .padding()
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
                statisticsService: services.statisticsService
            )
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fleet Overview")
                .font(.title2.bold())

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                SummaryCard(title: "Total", count: viewModel.printers.count, icon: "printer", color: .primary)
                SummaryCard(title: "Online", count: viewModel.onlineCount, icon: "wifi", color: .green)
                SummaryCard(title: "Printing", count: viewModel.printingCount, icon: "printer.fill", color: .blue)
                SummaryCard(title: "Paused", count: viewModel.pausedCount, icon: "pause.circle", color: .orange)
                SummaryCard(title: "Offline", count: viewModel.offlineCount, icon: "wifi.slash", color: .gray)
                SummaryCard(title: "Error", count: viewModel.errorCount, icon: "exclamationmark.triangle", color: .red)
            }
        }
    }

    // MARK: - Active Jobs (printers currently printing)

    private var activeJobsSection: some View {
        let printingPrinters = viewModel.printers.filter { $0.jobName != nil && $0.isOnline }
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
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
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

    // MARK: - Maintenance Alert

    private var maintenanceAlert: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.maintenanceCount) printer(s) in maintenance")
                    .font(.subheadline.weight(.medium))
                Text(viewModel.printersInMaintenance.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(count)")
                .font(.title2.bold().monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
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
        Text("Location Detail")
    case .createJob:
        Text("Create Job")
    case .createPrinter:
        Text("Create Printer")
    }
}

// MARK: - Active Job Row (printer with running job)

private struct ActiveJobRow: View {
    let printer: Printer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.jobName ?? "Unknown Job")
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
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}
