import Foundation

// MARK: - Prediction Request

struct PredictionRequest: Encodable, Sendable {
    let printerId: UUID
    let material: String?
    let estimatedDurationSeconds: Int?
}

// MARK: - Job Failure Prediction

struct JobFailurePrediction: Codable, Sendable {
    let printerId: UUID
    let material: String?
    let estimatedDurationMinutes: Double?
    let failureProbability: Double
    let predictedFailureLikelihood: Double?
    let riskLevel: String
    let factors: [PredictionFactor]
}

// MARK: - Prediction Factor

struct PredictionFactor: Codable, Sendable {
    let name: String
    let value: Double
    let weight: Double
}

// MARK: - Maintenance Forecast

struct MaintenanceForecast: Codable, Sendable {
    let printerId: UUID
    let printerName: String
    let upcomingTasks: [ForecastTask]
}

// MARK: - Forecast Task

struct ForecastTask: Codable, Sendable {
    let taskName: String
    let estimatedDaysUntilDue: Int
    let priority: String
}

// MARK: - Predictive Alert

struct PredictiveAlert: Codable, Sendable {
    let alertType: String
    let severity: String
    let message: String
    let recommendedAction: String
}
