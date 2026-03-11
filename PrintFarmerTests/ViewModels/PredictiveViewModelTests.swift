import XCTest
@testable import PrintFarmer

/// Tests for PredictiveViewModel: predicting failure, loading alerts and forecasts,
/// computing risk levels, and error handling.
@MainActor
final class PredictiveViewModelTests: XCTestCase {
    
    private var mockPredictiveService: MockPredictiveService!
    private var viewModel: PredictiveViewModel!
    private let testPrinterId = UUID()
    
    override func setUp() {
        super.setUp()
        mockPredictiveService = MockPredictiveService()
        viewModel = PredictiveViewModel()
        viewModel.configure(predictiveService: mockPredictiveService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockPredictiveService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func testInitialState() {
        XCTAssertNil(viewModel.prediction)
        XCTAssertTrue(viewModel.alerts.isEmpty)
        XCTAssertTrue(viewModel.forecasts.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Predict Failure Success
    
    func testPredictFailurePopulatesData() async {
        let prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: "PLA",
            estimatedDurationMinutes: 60.0,
            failureProbability: 0.65,
            predictedFailureLikelihood: 0.65,
            riskLevel: "high",
            factors: [
                PredictionFactor(
                    name: "Nozzle Wear",
                    value: 0.8,
                    weight: 0.4
                )
            ]
        )
        mockPredictiveService.predictionToReturn = prediction
        
        await viewModel.predictFailure(printerId: testPrinterId, material: "PLA", duration: 3600)
        
        XCTAssertNotNil(viewModel.prediction)
        XCTAssertEqual(viewModel.prediction?.printerId, testPrinterId)
        XCTAssertEqual(viewModel.prediction?.failureProbability, 0.65)
        XCTAssertEqual(viewModel.prediction?.riskLevel, "high")
        XCTAssertEqual(viewModel.prediction?.factors.count, 1)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        
        let request = mockPredictiveService.predictJobFailureCalledWith
        XCTAssertEqual(request?.printerId, testPrinterId)
        XCTAssertEqual(request?.material, "PLA")
        XCTAssertEqual(request?.estimatedDurationSeconds, 3600)
    }
    
    func testPredictFailureHandlesError() async {
        mockPredictiveService.errorToThrow = TestError.generic
        
        await viewModel.predictFailure(printerId: testPrinterId, material: "PETG", duration: 7200)
        
        XCTAssertNil(viewModel.prediction)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testPredictFailureClearsPreviousError() async {
        mockPredictiveService.errorToThrow = TestError.generic
        await viewModel.predictFailure(printerId: testPrinterId, material: "PLA", duration: 3600)
        XCTAssertNotNil(viewModel.error)
        
        mockPredictiveService.errorToThrow = nil
        mockPredictiveService.predictionToReturn = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.2,
            predictedFailureLikelihood: nil,
            riskLevel: "low",
            factors: []
        )
        
        await viewModel.predictFailure(printerId: testPrinterId, material: "PLA", duration: 3600)
        
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Load Alerts
    
    func testLoadAlertsPopulatesData() async {
        let alert = PredictiveAlert(
            alertType: "maintenance_overdue",
            severity: "warning",
            message: "Maintenance is overdue for Prusa MK3",
            recommendedAction: "Schedule maintenance immediately"
        )
        mockPredictiveService.alertsToReturn = [alert]
        
        await viewModel.loadAlerts()
        
        XCTAssertEqual(viewModel.alerts.count, 1)
        XCTAssertEqual(viewModel.alerts.first?.alertType, "maintenance_overdue")
        XCTAssertEqual(viewModel.alerts.first?.severity, "warning")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(mockPredictiveService.getActiveAlertsCalled)
    }
    
    func testLoadAlertsHandlesError() async {
        mockPredictiveService.errorToThrow = TestError.generic
        
        await viewModel.loadAlerts()
        
        XCTAssertTrue(viewModel.alerts.isEmpty)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Load Forecasts
    
    func testLoadForecastsPopulatesData() async {
        let forecast = MaintenanceForecast(
            printerId: testPrinterId,
            printerName: "Prusa MK3",
            upcomingTasks: [
                ForecastTask(
                    taskName: "Nozzle Replacement",
                    estimatedDaysUntilDue: 7,
                    priority: "high"
                )
            ]
        )
        mockPredictiveService.forecastsToReturn = [forecast]
        
        await viewModel.loadForecasts()
        
        XCTAssertEqual(viewModel.forecasts.count, 1)
        XCTAssertEqual(viewModel.forecasts.first?.printerId, testPrinterId)
        XCTAssertEqual(viewModel.forecasts.first?.upcomingTasks.count, 1)
        XCTAssertEqual(viewModel.forecasts.first?.upcomingTasks.first?.taskName, "Nozzle Replacement")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockPredictiveService.getMaintenanceForecastCalledWith, 30)
    }
    
    func testLoadForecastsHandlesError() async {
        mockPredictiveService.errorToThrow = TestError.generic
        
        await viewModel.loadForecasts()
        
        XCTAssertTrue(viewModel.forecasts.isEmpty)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Computed Properties
    
    func testRiskPercentageConvertsTo0To100Scale() {
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.0,
            predictedFailureLikelihood: nil,
            riskLevel: "low",
            factors: []
        )
        XCTAssertEqual(viewModel.riskPercentage, 0)
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.25,
            predictedFailureLikelihood: nil,
            riskLevel: "low",
            factors: []
        )
        XCTAssertEqual(viewModel.riskPercentage, 25)
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.50,
            predictedFailureLikelihood: nil,
            riskLevel: "moderate",
            factors: []
        )
        XCTAssertEqual(viewModel.riskPercentage, 50)
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.75,
            predictedFailureLikelihood: nil,
            riskLevel: "high",
            factors: []
        )
        XCTAssertEqual(viewModel.riskPercentage, 75)
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 1.0,
            predictedFailureLikelihood: nil,
            riskLevel: "critical",
            factors: []
        )
        XCTAssertEqual(viewModel.riskPercentage, 100)
    }
    
    func testRiskPercentageReturnsZeroWhenNoPrediction() {
        viewModel.prediction = nil
        
        XCTAssertEqual(viewModel.riskPercentage, 0)
    }
    
    func testRiskLevelReturnsCorrectLevel() {
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.10,
            predictedFailureLikelihood: nil,
            riskLevel: "low",
            factors: []
        )
        XCTAssertEqual(viewModel.riskLevel, "Low")
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.30,
            predictedFailureLikelihood: nil,
            riskLevel: "moderate",
            factors: []
        )
        XCTAssertEqual(viewModel.riskLevel, "Moderate")
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.60,
            predictedFailureLikelihood: nil,
            riskLevel: "high",
            factors: []
        )
        XCTAssertEqual(viewModel.riskLevel, "High")
        
        viewModel.prediction = JobFailurePrediction(
            printerId: testPrinterId,
            material: nil,
            estimatedDurationMinutes: nil,
            failureProbability: 0.85,
            predictedFailureLikelihood: nil,
            riskLevel: "critical",
            factors: []
        )
        XCTAssertEqual(viewModel.riskLevel, "Critical")
    }
    
    func testRiskLevelReturnsLowWhenNoPrediction() {
        viewModel.prediction = nil
        
        XCTAssertEqual(viewModel.riskLevel, "Low")
    }
    
    // MARK: - Unconfigured Guard
    
    func testPredictFailureDoesNothingWhenUnconfigured() async {
        viewModel = PredictiveViewModel()
        
        await viewModel.predictFailure(printerId: testPrinterId, material: "PLA", duration: 3600)
        
        XCTAssertNil(viewModel.prediction)
        XCTAssertNil(mockPredictiveService.predictJobFailureCalledWith)
    }
    
    func testLoadAlertsDoesNothingWhenUnconfigured() async {
        viewModel = PredictiveViewModel()
        
        await viewModel.loadAlerts()
        
        XCTAssertTrue(viewModel.alerts.isEmpty)
        XCTAssertFalse(mockPredictiveService.getActiveAlertsCalled)
    }
    
    func testLoadForecastsDoesNothingWhenUnconfigured() async {
        viewModel = PredictiveViewModel()
        
        await viewModel.loadForecasts()
        
        XCTAssertTrue(viewModel.forecasts.isEmpty)
        XCTAssertNil(mockPredictiveService.getMaintenanceForecastCalledWith)
    }
}
