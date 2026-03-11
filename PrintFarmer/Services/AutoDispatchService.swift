import Foundation

// MARK: - AutoDispatch Service

actor AutoDispatchService: AutoDispatchServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func getAllStatus() async throws -> [AutoDispatchStatus] {
        try await apiClient.get("/api/autoprint/status")
    }

    func getStatus(printerId: UUID) async throws -> AutoDispatchStatus {
        try await apiClient.get("/api/autoprint/\(printerId)/status")
    }

    func markReady(printerId: UUID) async throws -> AutoDispatchReadyResult {
        try await apiClient.post("/api/autoprint/\(printerId)/ready")
    }

    func skip(printerId: UUID) async throws -> AutoDispatchStatus {
        try await apiClient.post("/api/autoprint/\(printerId)/skip")
    }

    func cancel(printerId: UUID) async throws -> AutoDispatchStatus {
        try await apiClient.post("/api/autoprint/\(printerId)/cancel")
    }

    func setEnabled(printerId: UUID, request: SetAutoDispatchEnabledRequest) async throws -> AutoDispatchStatus {
        try await apiClient.put("/api/autoprint/\(printerId)/enabled", body: request)
    }
}
