import Foundation
import os

@MainActor @Observable
final class DispatchViewModel {
    var queueStatus: DispatchQueueStatus?
    var history: [DispatchHistoryEntry] = []
    var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "Dispatch")
    private var dispatchService: (any DispatchServiceProtocol)?

    func configure(dispatchService: any DispatchServiceProtocol) {
        self.dispatchService = dispatchService
    }

    func loadQueueStatus() async {
        guard let dispatchService else { return }
        isLoading = true
        error = nil

        do {
            queueStatus = try await dispatchService.getQueueStatus()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadHistory() async {
        guard let dispatchService else { return }
        do {
            let page = try await dispatchService.getHistory(page: 1, pageSize: 50)
            history = page.items
        } catch {
            logger.warning("Failed to load dispatch history: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed

    var pendingJobCount: Int { queueStatus?.pendingUnassignedJobs ?? 0 }
    var idlePrinterCount: Int { queueStatus?.idlePrinters ?? 0 }
    var busyPrinterCount: Int { queueStatus?.busyPrinters ?? 0 }
}
