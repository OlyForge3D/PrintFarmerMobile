import Foundation

@Observable
final class DashboardViewModel: @unchecked Sendable {
    var printers: [Printer] = []
    var activeJobs: [PrintJob] = []
    var isLoading = false
    var errorMessage: String?

    private let printerService: PrinterService
    private let jobService: JobService

    init(printerService: PrinterService, jobService: JobService) {
        self.printerService = printerService
        self.jobService = jobService
    }

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            async let printersTask = printerService.list()
            async let jobsTask = jobService.list()
            printers = try await printersTask
            activeJobs = try await jobsTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    var onlinePrinters: [Printer] {
        printers.filter(\.isOnline)
    }

    var printingJobs: [PrintJob] {
        activeJobs.filter { $0.status == .printing }
    }
}
