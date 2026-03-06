import Foundation

@MainActor @Observable
final class DashboardViewModel {
    var printers: [Printer] = []
    var queueOverview: [QueueOverview] = []
    var summary: StatisticsSummary?
    var isLoading = false
    var errorMessage: String?

    private var printerService: (any PrinterServiceProtocol)?
    private var jobService: (any JobServiceProtocol)?
    private var statisticsService: (any StatisticsServiceProtocol)?

    func configure(
        printerService: any PrinterServiceProtocol,
        jobService: any JobServiceProtocol,
        statisticsService: any StatisticsServiceProtocol
    ) {
        self.printerService = printerService
        self.jobService = jobService
        self.statisticsService = statisticsService
    }

    func loadDashboard() async {
        guard let printerService, let jobService else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let printersTask = printerService.list()
            async let queueTask = jobService.list()
            printers = try await printersTask
            queueOverview = try await queueTask

            summary = try? await statisticsService?.getSummary()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Computed Summaries

    var onlineCount: Int { printers.filter(\.isOnline).count }

    var printingCount: Int {
        printers.filter { $0.state?.lowercased() == "printing" }.count
    }

    var pausedCount: Int {
        printers.filter { $0.state?.lowercased() == "paused" }.count
    }

    var offlineCount: Int { printers.filter { !$0.isOnline }.count }

    var errorCount: Int {
        printers.filter { $0.state?.lowercased() == "error" }.count
    }

    var maintenanceCount: Int {
        printers.filter(\.inMaintenance).count
    }

    var activeJobCount: Int {
        queueOverview.filter { $0.currentJobId != nil }.count
    }

    var queuedJobCount: Int {
        queueOverview.reduce(0) { $0 + $1.queuedJobsCount }
    }

    var hasMaintenanceAlerts: Bool { maintenanceCount > 0 }

    var printersInMaintenance: [Printer] {
        printers.filter(\.inMaintenance)
    }
}
