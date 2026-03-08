import XCTest
@testable import PrintFarmer

/// Tests for AutoPrintViewModel: loading status, marking ready, skipping, toggling enabled state,
/// and error handling.
@MainActor
final class AutoPrintViewModelTests: XCTestCase {
    
    private var mockAutoPrintService: MockAutoPrintService!
    private var viewModel: AutoPrintViewModel!
    private let testPrinterId = UUID()
    
    override func setUp() {
        super.setUp()
        mockAutoPrintService = MockAutoPrintService()
        viewModel = AutoPrintViewModel()
        viewModel.configure(autoPrintService: mockAutoPrintService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockAutoPrintService = nil
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
        let status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "ready",
            queuedJobCount: 3
        )
        mockAutoPrintService.statusToReturn = status
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.status?.printerId, testPrinterId)
        XCTAssertEqual(viewModel.status?.autoPrintEnabled, true)
        XCTAssertEqual(viewModel.status?.state, "ready")
        XCTAssertEqual(viewModel.status?.queuedJobCount, 3)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockAutoPrintService.getStatusCalledWith, testPrinterId)
    }
    
    func testLoadStatusSetsLoadingState() async {
        let status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "ready",
            queuedJobCount: 0
        )
        mockAutoPrintService.statusToReturn = status
        
        let task = Task {
            await viewModel.loadStatus(printerId: testPrinterId)
        }
        
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        await task.value
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Load Status Error
    
    func testLoadStatusHandlesError() async {
        mockAutoPrintService.errorToThrow = TestError.generic
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.status)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadStatusClearsPreviousError() async {
        mockAutoPrintService.errorToThrow = TestError.generic
        await viewModel.loadStatus(printerId: testPrinterId)
        XCTAssertNotNil(viewModel.error)
        
        mockAutoPrintService.errorToThrow = nil
        mockAutoPrintService.statusToReturn = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: false,
            state: "idle",
            queuedJobCount: 0
        )
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Mark Ready
    
    func testMarkReadyUpdatesReadyResult() async {
        let readyResult = AutoPrintReadyResult(
            status: AutoPrintStatus(
                printerId: testPrinterId,
                autoPrintEnabled: true,
                state: "ready",
                queuedJobCount: 2
            ),
            nextJob: AutoPrintNextJob(
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
        mockAutoPrintService.readyResultToReturn = readyResult
        mockAutoPrintService.statusToReturn = readyResult.status
        
        await viewModel.markReady(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.readyResult)
        XCTAssertNotNil(viewModel.readyResult?.nextJob?.id)
        XCTAssertEqual(viewModel.readyResult?.filamentCheck?.sufficient, true)
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.status?.state, "ready")
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockAutoPrintService.markReadyCalledWith, testPrinterId)
    }
    
    func testMarkReadyHandlesError() async {
        mockAutoPrintService.errorToThrow = TestError.generic
        
        await viewModel.markReady(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.readyResult)
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Skip Job
    
    func testSkipUpdatesStatus() async {
        let status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "idle",
            queuedJobCount: 1
        )
        mockAutoPrintService.statusToReturn = status
        
        await viewModel.skip(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.status?.queuedJobCount, 1)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockAutoPrintService.skipCalledWith, testPrinterId)
    }
    
    func testSkipHandlesError() async {
        mockAutoPrintService.errorToThrow = TestError.generic
        
        await viewModel.skip(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Toggle Enabled
    
    func testToggleEnabledFromTrueToFalse() async {
        viewModel.status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "ready",
            queuedJobCount: 2
        )
        
        let newStatus = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: false,
            state: "idle",
            queuedJobCount: 2
        )
        mockAutoPrintService.statusToReturn = newStatus
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNotNil(mockAutoPrintService.setEnabledCalledWith)
        XCTAssertEqual(mockAutoPrintService.setEnabledCalledWith?.printerId, testPrinterId)
        XCTAssertEqual(mockAutoPrintService.setEnabledCalledWith?.request.enabled, false)
        XCTAssertEqual(viewModel.status?.autoPrintEnabled, false)
        XCTAssertNil(viewModel.error)
    }
    
    func testToggleEnabledFromFalseToTrue() async {
        viewModel.status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: false,
            state: "idle",
            queuedJobCount: 0
        )
        
        let newStatus = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "idle",
            queuedJobCount: 0
        )
        mockAutoPrintService.statusToReturn = newStatus
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNotNil(mockAutoPrintService.setEnabledCalledWith)
        XCTAssertEqual(mockAutoPrintService.setEnabledCalledWith?.request.enabled, true)
        XCTAssertEqual(viewModel.status?.autoPrintEnabled, true)
        XCTAssertNil(viewModel.error)
    }
    
    func testToggleEnabledDoesNothingWhenStatusIsNil() async {
        viewModel.status = nil
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNil(mockAutoPrintService.setEnabledCalledWith)
        XCTAssertNil(viewModel.status)
    }
    
    func testToggleEnabledHandlesError() async {
        viewModel.status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "ready",
            queuedJobCount: 1
        )
        mockAutoPrintService.errorToThrow = TestError.generic
        
        await viewModel.toggleEnabled(printerId: testPrinterId)
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.status?.autoPrintEnabled, true)
    }
    
    // MARK: - Computed Properties
    
    func testIsEnabledReturnsCorrectValue() {
        viewModel.status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "ready",
            queuedJobCount: 2
        )
        XCTAssertEqual(viewModel.isEnabled, true)
        
        viewModel.status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: false,
            state: "idle",
            queuedJobCount: 0
        )
        XCTAssertEqual(viewModel.isEnabled, false)
        
        viewModel.status = nil
        XCTAssertNil(viewModel.isEnabled)
    }
    
    func testCurrentStateReturnsCorrectValue() {
        viewModel.status = AutoPrintStatus(
            printerId: testPrinterId,
            autoPrintEnabled: true,
            state: "printing",
            queuedJobCount: 1
        )
        XCTAssertEqual(viewModel.currentState, "printing")
        
        viewModel.status = nil
        XCTAssertNil(viewModel.currentState)
    }
    
    // MARK: - Unconfigured Guard
    
    func testLoadStatusDoesNothingWhenUnconfigured() async {
        viewModel = AutoPrintViewModel()
        
        await viewModel.loadStatus(printerId: testPrinterId)
        
        XCTAssertNil(viewModel.status)
        XCTAssertNil(mockAutoPrintService.getStatusCalledWith)
    }
}
