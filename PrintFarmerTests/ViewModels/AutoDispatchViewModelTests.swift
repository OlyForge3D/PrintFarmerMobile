import XCTest
@testable import PrintFarmer

/// Tests for AutoDispatchViewModel: loading status, marking ready, skipping, toggling enabled state,
/// and error handling.
@MainActor
final class AutoDispatchViewModelTests: XCTestCase {
    
    private var mockAutoDispatchService: MockAutoDispatchService!
    private var viewModel: AutoDispatchViewModel!
    private let testPrinterId = UUID()
    
    override func setUp() {
        super.setUp()
        mockAutoDispatchService = MockAutoDispatchService()
        viewModel = AutoDispatchViewModel()
        viewModel.configure(autoDispatchService: mockAutoDispatchService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockAutoDispatchService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func testInitialState() {
        XCTAssertNil(viewModel.status)
        XCTAssertNil(viewModel.readyResult)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Load Status Success
    
    func testLoadStatusPopulatesData() async {
        let status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "ready",
            queuedJobCount: 3
        )
        mockAutoDispatchService.statusToReturn = status
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.status?.printerId, testPrinterId)
        XCTAssertEqual(viewModel.status?.autoDispatchEnabled, true)
        XCTAssertEqual(viewModel.status?.state, "ready")
        XCTAssertEqual(viewModel.status?.queuedJobCount, 3)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockAutoDispatchService.getStatusCalledWith, testPrinterId)
    }
    
    func testLoadStatusSetsLoadingState() async {
        let status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "ready",
            queuedJobCount: 0
        )
        mockAutoDispatchService.statusToReturn = status
        
        let task = Task {
            await viewModel.loadStatus(printerId: testPrinterId)
        }
        
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        await task.value
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Load Status Error
    
    func testLoadStatusHandlesError() async {
        mockAutoDispatchService.errorToThrow = TestError.generic
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.status)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadStatusClearsPreviousError() async {
        mockAutoDispatchService.errorToThrow = TestError.generic
        await viewModel.loadStatus(printerId: testPrinterId)
        XCTAssertNotNil(viewModel.error)
        
        mockAutoDispatchService.errorToThrow = nil
        mockAutoDispatchService.statusToReturn = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: false,
            state: "idle",
            queuedJobCount: 0
        )
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Mark Ready
    
    func testMarkReadyUpdatesReadyResult() async {
        let readyResult = AutoDispatchReadyResult(
            status: AutoDispatchStatus(
                printerId: testPrinterId,
                autoDispatchEnabled: true,
                state: "ready",
                queuedJobCount: 2
            ),
            nextJob: AutoDispatchNextJob(
                id: UUID(),
                name: "test_print.gcode",
                estimatedFilamentUsageG: 50.5,
                requiredMaterialType: nil,
                estimatedPrintTime: 3600
            ),
            filamentCheck: FilamentCheckResult(
                sufficient: true,
                remainingWeightG: 100.0,
                requiredWeightG: 50.5,
                loadedMaterial: nil,
                requiredMaterial: nil,
                materialMismatch: false,
                message: nil
            )
        )
        mockAutoDispatchService.readyResultToReturn = readyResult
        mockAutoDispatchService.statusToReturn = readyResult.status
        
        await viewModel.markReady(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.readyResult)
        XCTAssertNotNil(viewModel.readyResult?.nextJob?.id)
        XCTAssertEqual(viewModel.readyResult?.filamentCheck?.sufficient, true)
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.status?.state, "ready")
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockAutoDispatchService.markReadyCalledWith, testPrinterId)
    }
    
    func testMarkReadyHandlesError() async {
        mockAutoDispatchService.errorToThrow = TestError.generic
        
        await viewModel.markReady(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.readyResult)
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Skip Job
    
    func testSkipUpdatesStatus() async {
        let status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "idle",
            queuedJobCount: 1
        )
        mockAutoDispatchService.statusToReturn = status
        
        await viewModel.skip(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.status?.queuedJobCount, 1)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockAutoDispatchService.skipCalledWith, testPrinterId)
    }
    
    func testSkipHandlesError() async {
        mockAutoDispatchService.errorToThrow = TestError.generic
        
        await viewModel.skip(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Toggle Enabled
    
    func testToggleEnabledFromTrueToFalse() async {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "ready",
            queuedJobCount: 2
        )
        
        let newStatus = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: false,
            state: "idle",
            queuedJobCount: 2
        )
        mockAutoDispatchService.statusToReturn = newStatus
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNotNil(mockAutoDispatchService.setEnabledCalledWith)
        XCTAssertEqual(mockAutoDispatchService.setEnabledCalledWith?.printerId, testPrinterId)
        XCTAssertEqual(mockAutoDispatchService.setEnabledCalledWith?.request.enabled, false)
        XCTAssertEqual(viewModel.status?.autoDispatchEnabled, false)
        XCTAssertNil(viewModel.error)
    }
    
    func testToggleEnabledFromFalseToTrue() async {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: false,
            state: "idle",
            queuedJobCount: 0
        )
        
        let newStatus = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "idle",
            queuedJobCount: 0
        )
        mockAutoDispatchService.statusToReturn = newStatus
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNotNil(mockAutoDispatchService.setEnabledCalledWith)
        XCTAssertEqual(mockAutoDispatchService.setEnabledCalledWith?.request.enabled, true)
        XCTAssertEqual(viewModel.status?.autoDispatchEnabled, true)
        XCTAssertNil(viewModel.error)
    }
    
    func testToggleEnabledDoesNothingWhenStatusIsNil() async {
        viewModel.status = nil
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNil(mockAutoDispatchService.setEnabledCalledWith)
        XCTAssertNil(viewModel.status)
    }
    
    func testToggleEnabledHandlesError() async {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "ready",
            queuedJobCount: 1
        )
        mockAutoDispatchService.errorToThrow = TestError.generic
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.status?.autoDispatchEnabled, true)
    }
    
    // MARK: - Computed Properties
    
    func testIsEnabledReturnsCorrectValue() {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "ready",
            queuedJobCount: 2
        )
        XCTAssertEqual(viewModel.isEnabled, true)
        
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: false,
            state: "idle",
            queuedJobCount: 0
        )
        XCTAssertEqual(viewModel.isEnabled, false)
        
        viewModel.status = nil
        XCTAssertNil(viewModel.isEnabled)
    }
    
    func testCurrentStateReturnsCorrectValue() {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "printing",
            queuedJobCount: 1
        )
        XCTAssertEqual(viewModel.currentState, "printing")
        
        viewModel.status = nil
        XCTAssertNil(viewModel.currentState)
    }
    
    // MARK: - Parsed State Tests
    
    func testParsedStateReturnsPendingReady() {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "PendingReady",
            queuedJobCount: 1
        )
        
        XCTAssertEqual(viewModel.parsedState, .pendingReady)
    }
    
    func testParsedStateReturnsReady() {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "Ready",
            queuedJobCount: 1
        )
        
        XCTAssertEqual(viewModel.parsedState, .ready)
    }
    
    func testParsedStateReturnsNone() {
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: false,
            state: "None",
            queuedJobCount: 0
        )
        
        XCTAssertEqual(viewModel.parsedState, .none)
    }
    
    func testParsedStateReturnsNilWhenNoStatus() {
        viewModel.status = nil
        
        XCTAssertNil(viewModel.parsedState)
    }
    
    func testMarkReadyFromPendingReadyTransitionsToReady() async {
        // Set up status in PendingReady state
        viewModel.status = AutoDispatchStatus(
            printerId: testPrinterId,
            autoDispatchEnabled: true,
            state: "PendingReady",
            queuedJobCount: 1
        )
        
        // Configure mock to return Ready state after markReady
        let readyResult = AutoDispatchReadyResult(
            status: AutoDispatchStatus(
                printerId: testPrinterId,
                autoDispatchEnabled: true,
                state: "Ready",
                queuedJobCount: 1
            ),
            nextJob: AutoDispatchNextJob(
                id: UUID(),
                name: "test_job.gcode",
                estimatedFilamentUsageG: 25.0,
                requiredMaterialType: nil,
                estimatedPrintTime: 1800
            ),
            filamentCheck: FilamentCheckResult(
                sufficient: true,
                remainingWeightG: 500.0,
                requiredWeightG: 25.0,
                loadedMaterial: nil,
                requiredMaterial: nil,
                materialMismatch: false,
                message: nil
            )
        )
        mockAutoDispatchService.readyResultToReturn = readyResult
        mockAutoDispatchService.statusToReturn = readyResult.status
        
        // Call markReady
        await viewModel.markReady(printerId: testPrinterId)
        
        // Verify transition to Ready state
        XCTAssertEqual(viewModel.status?.state, "Ready")
        XCTAssertEqual(viewModel.parsedState, .ready)
        XCTAssertNotNil(viewModel.readyResult)
    }
    
    func testCurrentStateReturnsNilWhenStatusIsNil() {
        viewModel.status = nil
        
        XCTAssertNil(viewModel.currentState)
    }
    
    // MARK: - Unconfigured Guard
    
    func testLoadStatusDoesNothingWhenUnconfigured() async {
        viewModel = AutoDispatchViewModel()
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.status)
        XCTAssertNil(mockAutoDispatchService.getStatusCalledWith)
    }
}
