import XCTest
@testable import PrintFarmer

/// Tests for MaintenanceViewModel: loading alerts, upcoming tasks, uptime, cost data,
/// alert acknowledgment/dismissal, and error handling.
@MainActor
final class MaintenanceViewModelTests: XCTestCase {
    
    private var mockMaintenanceService: MockMaintenanceService!
    private var viewModel: MaintenanceViewModel!
    
    override func setUp() {
        super.setUp()
        mockMaintenanceService = MockMaintenanceService()
        viewModel = MaintenanceViewModel()
        viewModel.configure(maintenanceService: mockMaintenanceService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockMaintenanceService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func testInitialState() {
        XCTAssertTrue(viewModel.alerts.isEmpty)
        XCTAssertTrue(viewModel.upcomingTasks.isEmpty)
        XCTAssertTrue(viewModel.uptimeData.isEmpty)
        XCTAssertTrue(viewModel.costData.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Load Data Success
    
    func testLoadDataPopulatesAlertsAndTasks() async {
        let alert = MaintenanceAlert(
            id: UUID(),
            alertType: "warning",
            severity: "warning",
            message: "Nozzle wear detected",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        let task = UpcomingMaintenanceTask(
            id: UUID(),
            printerId: UUID(),
            printerName: "Prusa MK3",
            taskName: "Nozzle Replacement",
            componentName: nil,
            estimatedDueDate: Date().addingTimeInterval(86400 * 7),
            daysUntilDue: 7,
            isOverdue: false,
            priority: "medium"
        )
        mockMaintenanceService.alertsToReturn = [alert]
        mockMaintenanceService.upcomingTasksToReturn = [task]
        
        await viewModel.loadData()
        
        XCTAssertEqual(viewModel.alerts.count, 1)
        XCTAssertNotNil(viewModel.alerts.first?.id)
        XCTAssertEqual(viewModel.upcomingTasks.count, 1)
        XCTAssertNotNil(viewModel.upcomingTasks.first?.id)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    func testLoadDataPopulatesAnalyticsData() async {
        let uptime = PrinterUptime(
            printerName: "Prusa MK3",
            printerId: UUID(),
            uptimePercent: 95.5,
            maintenanceCount: 5,
            totalDowntimeMinutes: 180
        )
        let cost = MaintenanceCost(
            month: "2024-03",
            totalCost: Decimal(120.50)
        )
        mockMaintenanceService.alertsToReturn = []
        mockMaintenanceService.upcomingTasksToReturn = []
        mockMaintenanceService.uptimeToReturn = [uptime]
        mockMaintenanceService.costsToReturn = [cost]
        
        await viewModel.loadData()
        
        XCTAssertEqual(viewModel.uptimeData.count, 1)
        XCTAssertEqual(viewModel.uptimeData.first?.printerName, "Prusa MK3")
        XCTAssertEqual(viewModel.costData.count, 1)
        XCTAssertEqual(viewModel.costData.first?.totalCost, Decimal(120.50))
        XCTAssertNil(viewModel.error)
    }
    
    func testLoadDataSetsLoadingState() async {
        mockMaintenanceService.alertsToReturn = []
        mockMaintenanceService.upcomingTasksToReturn = []
        
        let task = Task {
            await viewModel.loadData()
        }
        
        // Check loading state is set
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        await task.value
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Load Data Error
    
    func testLoadDataHandlesError() async {
        mockMaintenanceService.errorToThrow = TestError.generic
        
        await viewModel.loadData()
        
        XCTAssertTrue(viewModel.alerts.isEmpty)
        XCTAssertTrue(viewModel.upcomingTasks.isEmpty)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadDataClearsPreviousError() async {
        mockMaintenanceService.errorToThrow = TestError.generic
        await viewModel.loadData()
        XCTAssertNotNil(viewModel.error)
        
        mockMaintenanceService.errorToThrow = nil
        mockMaintenanceService.alertsToReturn = []
        mockMaintenanceService.upcomingTasksToReturn = []
        
        await viewModel.loadData()
        
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Acknowledge Alert
    
    func testAcknowledgeAlertUpdatesAlert() async {
        let alert = MaintenanceAlert(
            id: UUID(),
            alertType: "warning",
            severity: "warning",
            message: "Nozzle wear detected",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        viewModel.alerts = [alert]
        
        let acknowledged = MaintenanceAlert(
            id: alert.id,
            alertType: "warning",
            severity: "warning",
            message: "Nozzle wear detected",
            printerId: alert.printerId,
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: alert.createdAt,
            acknowledgedAt: Date(),
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        mockMaintenanceService.alertToReturn = acknowledged
        
        await viewModel.acknowledgeAlert(alert)
        
        XCTAssertNotNil(mockMaintenanceService.acknowledgeAlertCalledWith)
        XCTAssertNotNil(viewModel.alerts.first?.acknowledgedAt)
        XCTAssertNil(viewModel.error)
    }
    
    func testAcknowledgeAlertHandlesError() async {
        let alert = MaintenanceAlert(
            id: UUID(),
            alertType: "warning",
            severity: "warning",
            message: "Nozzle wear detected",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        viewModel.alerts = [alert]
        mockMaintenanceService.errorToThrow = TestError.generic
        
        await viewModel.acknowledgeAlert(alert)
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertNil(viewModel.alerts.first?.acknowledgedAt)
    }
    
    // MARK: - Dismiss Alert
    
    func testDismissAlertUpdatesAlert() async {
        let alert = MaintenanceAlert(
            id: UUID(),
            alertType: "info",
            severity: "info",
            message: "Maintenance reminder",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        viewModel.alerts = [alert]
        
        let dismissed = MaintenanceAlert(
            id: alert.id,
            alertType: "info",
            severity: "info",
            message: "Maintenance reminder",
            printerId: alert.printerId,
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: alert.createdAt,
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: Date()
        )
        mockMaintenanceService.alertToReturn = dismissed
        
        await viewModel.dismissAlert(alert)
        
        XCTAssertNotNil(mockMaintenanceService.dismissAlertCalledWith)
        XCTAssertNotNil(viewModel.alerts.first?.dismissedAt)
        XCTAssertNil(viewModel.error)
    }
    
    func testDismissAlertHandlesError() async {
        let alert = MaintenanceAlert(
            id: UUID(),
            alertType: "info",
            severity: "info",
            message: "Maintenance reminder",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        viewModel.alerts = [alert]
        mockMaintenanceService.errorToThrow = TestError.generic
        
        await viewModel.dismissAlert(alert)
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertNil(viewModel.alerts.first?.dismissedAt)
    }
    
    // MARK: - Computed Properties
    
    func testActiveAlertsFiltersOutDismissedAndResolved() {
        let active = MaintenanceAlert(
            id: UUID(),
            alertType: "warning",
            severity: "warning",
            message: "Active alert",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: nil
        )
        let dismissed = MaintenanceAlert(
            id: UUID(),
            alertType: "info",
            severity: "info",
            message: "Dismissed alert",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: nil,
            acknowledgedBy: nil,
            resolvedAt: nil,
            dismissedAt: Date()
        )
        let resolved = MaintenanceAlert(
            id: UUID(),
            alertType: "error",
            severity: "error",
            message: "Resolved alert",
            printerId: UUID(),
            printerName: "Prusa MK3",
            recommendedAction: nil,
            createdAt: Date(),
            acknowledgedAt: Date(),
            acknowledgedBy: nil,
            resolvedAt: Date(),
            dismissedAt: nil
        )
        viewModel.alerts = [active, dismissed, resolved]
        
        let activeAlerts = viewModel.activeAlerts
        
        XCTAssertEqual(activeAlerts.count, 1)
        XCTAssertEqual(activeAlerts.first?.message, "Active alert")
    }
    
    func testSortedUpcomingTasksSortsByDueDate() {
        let farFuture = UpcomingMaintenanceTask(
            id: UUID(),
            printerId: UUID(),
            printerName: "Prusa MK3",
            taskName: "Belt Replacement",
            componentName: nil,
            estimatedDueDate: Date().addingTimeInterval(86400 * 30),
            daysUntilDue: 30,
            isOverdue: false,
            priority: "low"
        )
        let nearFuture = UpcomingMaintenanceTask(
            id: UUID(),
            printerId: UUID(),
            printerName: "Prusa MK3",
            taskName: "Nozzle Check",
            componentName: nil,
            estimatedDueDate: Date().addingTimeInterval(86400 * 3),
            daysUntilDue: 3,
            isOverdue: false,
            priority: "high"
        )
        viewModel.upcomingTasks = [farFuture, nearFuture]
        
        let sorted = viewModel.sortedUpcomingTasks
        
        XCTAssertEqual(sorted.count, 2)
        XCTAssertEqual(sorted.first?.taskName, "Nozzle Check")
        XCTAssertEqual(sorted.last?.taskName, "Belt Replacement")
    }
    
    // MARK: - Unconfigured Guard
    
    func testLoadDataDoesNothingWhenUnconfigured() async {
        viewModel = MaintenanceViewModel()
        
        await viewModel.loadData()
        
        XCTAssertTrue(viewModel.alerts.isEmpty)
        XCTAssertFalse(mockMaintenanceService.getAlertsCalled)
    }
}

enum TestError: Error {
    case generic
}
