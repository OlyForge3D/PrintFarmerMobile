import Foundation
@testable import PrintFarmer

final class MockPredictiveService: PredictiveServiceProtocol, @unchecked Sendable {
    var predictionToReturn: JobFailurePrediction?
    var forecastsToReturn: [MaintenanceForecast] = []
    var alertsToReturn: [PredictiveAlert] = []
    var errorToThrow: Error?
    
    // Call tracking
    var predictJobFailureCalledWith: PredictionRequest?
    var getMaintenanceForecastCalledWith: Int?
    var getActiveAlertsCalled = false
    
    func predictJobFailure(request: PredictionRequest) async throws -> JobFailurePrediction? {
        predictJobFailureCalledWith = request
        if let error = errorToThrow { throw error }
        return predictionToReturn
    }
    
    func getMaintenanceForecast(days: Int? = nil) async throws -> [MaintenanceForecast] {
        getMaintenanceForecastCalledWith = days
        if let error = errorToThrow { throw error }
        return forecastsToReturn
    }
    
    func getActiveAlerts() async throws -> [PredictiveAlert] {
        getActiveAlertsCalled = true
        if let error = errorToThrow { throw error }
        return alertsToReturn
    }
}
