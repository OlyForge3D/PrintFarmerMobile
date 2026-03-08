import Foundation

// MARK: - Predictive Service

actor PredictiveService: PredictiveServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func predictJobFailure(request: PredictionRequest) async throws -> JobFailurePrediction {
        try await apiClient.post("/api/predictive-analytics/predict-job-failure", body: request)
    }

    func getMaintenanceForecast(days: Int? = nil) async throws -> [MaintenanceForecast] {
        let query = days.map { "?days=\($0)" } ?? ""
        return try await apiClient.get("/api/predictive-analytics/maintenance-forecast\(query)")
    }

    func getActiveAlerts() async throws -> [PredictiveAlert] {
        try await apiClient.get("/api/predictive-analytics/active-alerts")
    }
}
