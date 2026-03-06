import Foundation

@Observable
final class JobListViewModel: @unchecked Sendable {
    var jobs: [PrintJob] = []
    var isLoading = false
    var errorMessage: String?

    private let jobService: JobService

    init(jobService: JobService) {
        self.jobService = jobService
    }

    func loadJobs() async {
        isLoading = true
        errorMessage = nil

        do {
            jobs = try await jobService.list()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func cancelJob(id: UUID) async {
        do {
            try await jobService.cancel(id: id)
            await loadJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
