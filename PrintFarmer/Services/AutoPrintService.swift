import Foundation

// MARK: - AutoPrint Service

actor AutoPrintService: AutoPrintServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func getAllStatus() async throws -> [AutoPrintStatus] {
        try await apiClient.get("/api/autoprint/status")
    }

    func getStatus(printerId: UUID) async throws -> AutoPrintStatus {
        try await apiClient.get("/api/autoprint/\(printerId)/status")
    }

    func markReady(printerId: UUID) async throws -> AutoPrintReadyResult {
        try await apiClient.post("/api/autoprint/\(printerId)/ready")
    }

    func skip(printerId: UUID) async throws -> AutoPrintStatus {
        try await apiClient.post("/api/autoprint/\(printerId)/skip")
    }

    func cancel(printerId: UUID) async throws -> AutoPrintStatus {
        try await apiClient.post("/api/autoprint/\(printerId)/cancel")
    }

    func setEnabled(printerId: UUID, request: SetAutoPrintEnabledRequest) async throws -> AutoPrintStatus {
        try await apiClient.put("/api/autoprint/\(printerId)/enabled", body: request)
    }
}
