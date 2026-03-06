import Foundation

@MainActor @Observable
final class JobListViewModel {
    var queueOverview: [QueueOverview] = []
    var isLoading = false
    var errorMessage: String?

    private var jobService: (any JobServiceProtocol)?

    func configure(jobService: any JobServiceProtocol) {
        self.jobService = jobService
    }

    func loadJobs() async {
        guard let jobService else { return }
        isLoading = true
        errorMessage = nil

        do {
            queueOverview = try await jobService.list()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func cancelJob(id: UUID) async {
        guard let jobService else { return }
        do {
            try await jobService.cancel(id: id)
            await loadJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func abortJob(id: UUID) async {
        guard let jobService else { return }
        do {
            try await jobService.abort(id: id)
            await loadJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var printersWithActiveJobs: [QueueOverview] {
        queueOverview.filter { $0.currentJobId != nil }
    }

    var printersWithQueuedJobs: [QueueOverview] {
        queueOverview.filter { $0.queuedJobsCount > 0 }
    }

    var availablePrinters: [QueueOverview] {
        queueOverview.filter { $0.isAvailable && $0.currentJobId == nil }
    }
}
