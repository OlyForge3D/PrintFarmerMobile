import Foundation

// MARK: - Job Service

actor JobService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func list() async throws -> [PrintJob] {
        try await apiClient.get("/api/jobqueue")
    }

    func get(id: UUID) async throws -> PrintJob {
        try await apiClient.get("/api/jobqueue/\(id)")
    }

    func create(_ request: CreatePrintJobRequest) async throws -> PrintJob {
        try await apiClient.post("/api/jobqueue", body: request)
    }

    func update(id: UUID, _ request: UpdatePrintJobRequest) async throws -> PrintJob {
        try await apiClient.put("/api/jobqueue/\(id)", body: request)
    }

    func cancel(id: UUID) async throws {
        try await apiClient.post("/api/jobqueue/\(id)/cancel")
    }

    func dispatch(id: UUID) async throws {
        try await apiClient.post("/api/jobqueue/\(id)/dispatch")
    }

    func abort(id: UUID) async throws {
        try await apiClient.post("/api/jobqueue/\(id)/abort")
    }
}
