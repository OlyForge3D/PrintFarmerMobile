import Foundation
import os

@MainActor @Observable
final class PredictiveViewModel {
    var prediction: JobFailurePrediction?
    var alerts: [PredictiveAlert] = []
    var forecasts: [MaintenanceForecast] = []
    var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "Predictive")
    private var predictiveService: (any PredictiveServiceProtocol)?

    func configure(predictiveService: any PredictiveServiceProtocol) {
        self.predictiveService = predictiveService
    }

    func predictFailure(printerId: UUID, material: String?, duration: TimeInterval?) async {
        guard let predictiveService else { return }
        isLoading = true
        error = nil

        do {
            let request = PredictionRequest(
                printerId: printerId,
                material: material,
                estimatedDurationSeconds: duration.map { Int($0) }
            )
            prediction = try await predictiveService.predictJobFailure(request: request)
        } catch {
            logger.warning("Failed to predict failure: \(error.localizedDescription)")
            // Don't show error for network/decode failures — show empty state instead
            prediction = nil
        }

        isLoading = false
    }

    func loadAlerts() async {
        guard let predictiveService else { return }
        do {
            alerts = try await predictiveService.getActiveAlerts()
        } catch {
            logger.warning("Failed to load predictive alerts: \(error.localizedDescription)")
        }
    }

    func loadForecasts() async {
        guard let predictiveService else { return }
        do {
            forecasts = try await predictiveService.getMaintenanceForecast(days: 30)
        } catch {
            logger.warning("Failed to load forecasts: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed

    var riskPercentage: Int {
        Int((prediction?.failureProbability ?? 0) * 100)
    }

    var riskLevel: String {
        switch riskPercentage {
        case 0..<25: return "Low"
        case 25..<50: return "Moderate"
        case 50..<75: return "High"
        default: return "Critical"
        }
    }
}
