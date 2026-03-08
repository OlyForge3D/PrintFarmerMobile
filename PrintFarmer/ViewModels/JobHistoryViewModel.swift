import Foundation
import os

@MainActor @Observable
final class JobHistoryViewModel {
    var historyPage: QueueHistoryPage?
    var timeline: [TimelineEvent] = []
    var selectedJobHistory: JobStateHistory?
    var isLoading = false
    var isLoadingMore = false
    var error: String?
    var currentOffset = 0

    var dateFrom: Date?
    var dateTo: Date?

    private let pageSize = 30
    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "JobHistory")
    private var jobAnalyticsService: (any JobAnalyticsServiceProtocol)?

    func configure(jobAnalyticsService: any JobAnalyticsServiceProtocol) {
        self.jobAnalyticsService = jobAnalyticsService
    }

    func loadHistory() async {
        guard let jobAnalyticsService else { return }
        isLoading = true
        error = nil
        currentOffset = 0

        do {
            historyPage = try await jobAnalyticsService.getHistory(
                limit: pageSize,
                offset: 0,
                sortBy: nil,
                statuses: nil,
                dateStart: dateFrom,
                dateEnd: dateTo
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard let jobAnalyticsService, !isLoadingMore else { return }
        guard let page = historyPage, page.entries.count < page.totalCount else { return }

        isLoadingMore = true
        currentOffset += pageSize

        do {
            let nextPage = try await jobAnalyticsService.getHistory(
                limit: pageSize,
                offset: currentOffset,
                sortBy: nil,
                statuses: nil,
                dateStart: dateFrom,
                dateEnd: dateTo
            )
            historyPage = QueueHistoryPage(
                entries: (historyPage?.entries ?? []) + nextPage.entries,
                totalCount: nextPage.totalCount,
                currentPage: nextPage.currentPage,
                pageSize: nextPage.pageSize,
                stats: nextPage.stats
            )
        } catch {
            logger.warning("Failed to load more history: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    func loadTimeline(dateFrom: Date?, dateTo: Date?) async {
        guard let jobAnalyticsService else { return }
        do {
            timeline = try await jobAnalyticsService.getTimeline(
                dateFrom: dateFrom,
                dateTo: dateTo,
                printerId: nil,
                filterStatus: nil,
                limit: 100
            )
        } catch {
            logger.warning("Failed to load timeline: \(error.localizedDescription)")
        }
    }

    func loadJobStateHistory(jobId: String) async {
        guard let jobAnalyticsService else { return }
        do {
            selectedJobHistory = try await jobAnalyticsService.getJobStateHistory(jobId: jobId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Computed

    var historyItems: [QueueHistoryEntry] {
        historyPage?.entries ?? []
    }

    var canLoadMore: Bool {
        guard let page = historyPage else { return false }
        return page.entries.count < page.totalCount
    }
}
