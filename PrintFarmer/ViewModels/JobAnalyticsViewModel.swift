import Foundation
import os

@MainActor @Observable
final class JobAnalyticsViewModel {
    var jobs: [QueuedJobWithMeta] = []
    var stats: QueueStats?
    var modelStats: [QueuePrinterModelStats] = []
    var selectedStatus: String?
    var selectedModel: String?
    var selectedMaterial: String?
    var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "JobAnalytics")
    private var jobAnalyticsService: (any JobAnalyticsServiceProtocol)?

    func configure(jobAnalyticsService: any JobAnalyticsServiceProtocol) {
        self.jobAnalyticsService = jobAnalyticsService
    }

    func loadJobs() async {
        guard let jobAnalyticsService else { return }
        isLoading = true
        error = nil

        do {
            jobs = try await jobAnalyticsService.getQueuedJobs(
                filterStatus: selectedStatus,
                filterModel: selectedModel,
                filterMaterial: selectedMaterial,
                limit: 50,
                offset: 0
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadStats() async {
        guard let jobAnalyticsService else { return }

        do {
            async let statsTask = jobAnalyticsService.getStats()
            async let modelStatsTask = jobAnalyticsService.getModelStats()
            stats = try await statsTask
            modelStats = try await modelStatsTask
        } catch {
            logger.warning("Failed to load job stats: \(error.localizedDescription)")
        }
    }

    func applyFilters() async {
        await loadJobs()
    }

    func clearFilters() {
        selectedStatus = nil
        selectedModel = nil
        selectedMaterial = nil
    }
}
