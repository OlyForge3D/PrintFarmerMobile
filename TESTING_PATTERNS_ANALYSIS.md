# PFarm-iOS Testing & Source Code Analysis

## 1. TESTING PATTERNS

### 1.1 MockSpoolService.swift — Full Mock Pattern
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/Mocks/MockSpoolService.swift`

```swift
import Foundation
@testable import PrintFarmer

final class MockSpoolService: SpoolServiceProtocol, @unchecked Sendable {
    var spoolsPageToReturn = SpoolmanPagedResult<SpoolmanSpool>(items: [], totalCount: 0)
    var spoolToReturn: SpoolmanSpool?
    var filamentsToReturn: [SpoolmanFilament] = []
    var vendorsToReturn: [SpoolmanVendor] = []
    var materialsToReturn: [SpoolmanMaterial] = []
    var errorToThrow: Error?

    // Call tracking
    var listSpoolsCalled = false
    // swiftlint:disable:next large_tuple
    var listSpoolsArgs: (limit: Int, offset: Int, search: String?, material: String?, vendor: String?)?
    var createSpoolCalledWith: SpoolmanSpoolRequest?
    var updateSpoolCalledWith: (id: Int, request: SpoolmanSpoolRequest)?
    var deleteSpoolCalledWith: Int?
    var listFilamentsCalled = false
    var listVendorsCalled = false
    var listMaterialsCalled = false

    func listSpools(limit: Int, offset: Int, search: String?, material: String?, vendor: String?) async throws -> SpoolmanPagedResult<SpoolmanSpool> {
        listSpoolsCalled = true
        listSpoolsArgs = (limit, offset, search, material, vendor)
        if let error = errorToThrow { throw error }
        return spoolsPageToReturn
    }

    func createSpool(_ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool {
        createSpoolCalledWith = request
        if let error = errorToThrow { throw error }
        guard let spool = spoolToReturn else { throw NetworkError.notFound }
        return spool
    }

    func updateSpool(id: Int, _ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool {
        updateSpoolCalledWith = (id, request)
        if let error = errorToThrow { throw error }
        guard let spool = spoolToReturn else { throw NetworkError.notFound }
        return spool
    }

    func deleteSpool(id: Int) async throws {
        deleteSpoolCalledWith = id
        if let error = errorToThrow { throw error }
    }

    func listFilaments() async throws -> [SpoolmanFilament] {
        listFilamentsCalled = true
        if let error = errorToThrow { throw error }
        return filamentsToReturn
    }

    func listVendors() async throws -> [SpoolmanVendor] {
        listVendorsCalled = true
        if let error = errorToThrow { throw error }
        return vendorsToReturn
    }

    func listMaterials() async throws -> [SpoolmanMaterial] {
        listMaterialsCalled = true
        if let error = errorToThrow { throw error }
        return materialsToReturn
    }

    func reset() {
        spoolsPageToReturn = SpoolmanPagedResult<SpoolmanSpool>(items: [], totalCount: 0)
        spoolToReturn = nil
        filamentsToReturn = []
        vendorsToReturn = []
        materialsToReturn = []
        errorToThrow = nil
        listSpoolsCalled = false
        listSpoolsArgs = nil
        createSpoolCalledWith = nil
        updateSpoolCalledWith = nil
        deleteSpoolCalledWith = nil
        listFilamentsCalled = false
        listVendorsCalled = false
        listMaterialsCalled = false
    }
}
```

**Key Mock Patterns:**
- ✅ Conforms to `SpoolServiceProtocol` with `@unchecked Sendable` for async compatibility
- ✅ State management: Return values for different scenarios
- ✅ Call tracking: Captures which methods were called and with what arguments
- ✅ Error injection: `errorToThrow` property for testing error paths
- ✅ Reset method: Clears all state between tests
- ✅ Tuple argument capture for multi-parameter methods (listSpools)
- ✅ Guards against missing return values (throws NetworkError.notFound)

---

### 1.2 PrinterListViewModelTests.swift — ViewModel Test Pattern
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/ViewModels/PrinterListViewModelTests.swift`

```swift
import XCTest
@testable import PrintFarmer

/// Tests for PrinterListViewModel: loading, error handling, filtering,
/// and search using MockPrinterService via configure() DI pattern.
@MainActor
final class PrinterListViewModelTests: XCTestCase {

    private var mockService: MockPrinterService!
    private var viewModel: PrinterListViewModel!

    override func setUp() {
        super.setUp()
        mockService = MockPrinterService()
        viewModel = PrinterListViewModel()
        viewModel.configure(printerService: mockService)
    }

    override func tearDown() {
        viewModel = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - Initial State
    
    func testInitialState() {
        XCTAssertTrue(viewModel.printers.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.selectedStatus, .all)
    }

    // MARK: - Load Printers
    
    func testLoadPrintersSuccessPopulatesList() async throws {
        let printer = try TestData.decodePrinter()
        mockService.printersToReturn = [printer]

        await viewModel.loadPrinters()

        XCTAssertEqual(viewModel.printers.count, 1)
        XCTAssertTrue(mockService.listPrintersCalled)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadPrintersEmptyList() async {
        mockService.printersToReturn = []

        await viewModel.loadPrinters()

        XCTAssertTrue(viewModel.printers.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadPrintersError() async {
        mockService.errorToThrow = NetworkError.noConnection

        await viewModel.loadPrinters()

        XCTAssertTrue(viewModel.printers.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Search Filtering
    
    func testSearchFiltersByName() async throws {
        let mk4 = try TestData.decodePrinter(from: TestJSON.printer)
        let ender = try TestData.decodePrinter(from: TestJSON.printerMinimal)
        mockService.printersToReturn = [mk4, ender]
        await viewModel.loadPrinters()

        viewModel.searchText = "Prusa"
        XCTAssertEqual(viewModel.filteredPrinters.count, 1)
        XCTAssertEqual(viewModel.filteredPrinters.first?.name, "Prusa MK4")
    }

    func testSearchIsCaseInsensitive() async throws {
        let printer = try TestData.decodePrinter(from: TestJSON.printer)
        mockService.printersToReturn = [printer]
        await viewModel.loadPrinters()

        viewModel.searchText = "prusa"
        XCTAssertEqual(viewModel.filteredPrinters.count, 1)
    }

    func testEmptySearchReturnsAll() async throws {
        let mk4 = try TestData.decodePrinter(from: TestJSON.printer)
        let ender = try TestData.decodePrinter(from: TestJSON.printerMinimal)
        mockService.printersToReturn = [mk4, ender]
        await viewModel.loadPrinters()

        viewModel.searchText = ""
        XCTAssertEqual(viewModel.filteredPrinters.count, 2)
    }

    // MARK: - Status Filtering
    
    func testFilterByOnline() async throws {
        let online = try TestData.decodePrinter(from: TestJSON.printer)     // isOnline: true
        let offline = try TestData.decodePrinter(from: TestJSON.printerMinimal) // isOnline: false
        mockService.printersToReturn = [online, offline]
        await viewModel.loadPrinters()

        viewModel.selectedStatus = .online
        XCTAssertEqual(viewModel.filteredPrinters.count, 1)
        XCTAssertEqual(viewModel.filteredPrinters.first?.name, "Prusa MK4")
    }

    func testFilterByOffline() async throws {
        let online = try TestData.decodePrinter(from: TestJSON.printer)
        let offline = try TestData.decodePrinter(from: TestJSON.printerMinimal)
        mockService.printersToReturn = [online, offline]
        await viewModel.loadPrinters()

        viewModel.selectedStatus = .offline
        XCTAssertEqual(viewModel.filteredPrinters.count, 1)
        XCTAssertEqual(viewModel.filteredPrinters.first?.name, "Ender 3")
    }

    func testFilterByPrinting() async throws {
        let printing = try TestData.decodePrinter(from: TestJSON.printer) // state: "printing"
        let offline = try TestData.decodePrinter(from: TestJSON.printerMinimal) // state: nil
        mockService.printersToReturn = [printing, offline]
        await viewModel.loadPrinters()

        viewModel.selectedStatus = .printing
        XCTAssertEqual(viewModel.filteredPrinters.count, 1)
    }

    func testFilterAllShowsEverything() async throws {
        let mk4 = try TestData.decodePrinter(from: TestJSON.printer)
        let ender = try TestData.decodePrinter(from: TestJSON.printerMinimal)
        mockService.printersToReturn = [mk4, ender]
        await viewModel.loadPrinters()

        viewModel.selectedStatus = .all
        XCTAssertEqual(viewModel.filteredPrinters.count, 2)
    }

    // MARK: - Pull to Refresh
    
    func testPullToRefreshReloadsData() async throws {
        mockService.printersToReturn = []
        await viewModel.loadPrinters()
        XCTAssertEqual(viewModel.printers.count, 0)

        let printer = try TestData.decodePrinter()
        mockService.printersToReturn = [printer]
        await viewModel.loadPrinters()

        XCTAssertEqual(viewModel.printers.count, 1)
    }

    func testRefreshClearsError() async {
        mockService.errorToThrow = NetworkError.noConnection
        await viewModel.loadPrinters()
        XCTAssertNotNil(viewModel.errorMessage)

        mockService.errorToThrow = nil
        mockService.printersToReturn = []
        await viewModel.loadPrinters()

        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Not Configured
    
    func testLoadWithoutConfigureDoesNotCrash() async {
        let unconfigured = PrinterListViewModel()
        await unconfigured.loadPrinters()
        XCTAssertFalse(unconfigured.isLoading)
    }
}
```

**Key ViewModel Test Patterns:**
- ✅ `@MainActor` annotation for testing UI-bound ViewModels
- ✅ Dependency injection via `configure()` method
- ✅ setUp/tearDown for clean test isolation
- ✅ Tests grouped by MARK sections (Initial State, Load, Filtering, etc.)
- ✅ Async/await support with `await` keyword on async methods
- ✅ Error path testing via mock error injection
- ✅ Computed property testing (filteredPrinters)
- ✅ State mutation testing (searchText, selectedStatus)
- ✅ Edge cases (empty lists, unconfigured ViewModels)

---

### 1.3 TestFixtures.swift — Fixture & Factory Pattern
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/Helpers/TestFixtures.swift`

```swift
import Foundation
@testable import PrintFarmer

// MARK: - JSON Fixtures

/// Realistic JSON payloads derived from the Printfarmer backend DTOs.
enum TestJSON {

    // MARK: Printer (CompletePrinterDto)
    
    static let printer = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Prusa MK4",
        "notes": "Workshop printer",
        "manufacturerId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "manufacturerName": "Prusa Research",
        "modelId": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
        "modelName": "MK4",
        "motionType": "Cartesian",
        "backend": "Moonraker",
        "apiKey": "test-api-key",
        "originalServerUrl": "http://192.168.1.100",
        "backendPort": 7125,
        "frontendPort": 80,
        "inMaintenance": false,
        "isEnabled": true,
        "isOnline": true,
        "state": "printing",
        "progress": 45.5,
        "jobName": "benchy.gcode",
        "thumbnailUrl": "http://192.168.1.100/thumb/benchy.png",
        "cameraStreamUrl": "http://192.168.1.100:8080/?action=stream",
        "x": 120.0,
        "y": 85.5,
        "z": 12.3,
        "hotendTemp": 215.0,
        "bedTemp": 60.0,
        "hotendTarget": 215.0,
        "bedTarget": 60.0,
        "homedAxes": "xyz",
        "spoolInfo": {
            "hasActiveSpool": true,
            "activeSpoolId": 42,
            "spoolName": "PLA Basic Black",
            "material": "PLA",
            "colorHex": "#000000",
            "filamentName": "Prusament PLA",
            "vendor": "Prusa Research",
            "remainingWeightG": 750.0,
            "spoolInUse": true
        },
        "backendUrl": "http://192.168.1.100:7125",
        "frontendUrl": "http://192.168.1.100",
        "location": {
            "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
            "name": "Workshop",
            "description": "Main workshop area"
        }
    }
    """

    static let printerMinimal = """
    {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "name": "Ender 3",
        "backend": "Moonraker",
        "backendPort": 7125,
        "inMaintenance": false,
        "isEnabled": true,
        "isOnline": false
    }
    """

    static let printerArray = "[\(printer), \(printerMinimal)]"

    // [Full PrintJob, Location, Auth, Notification, Statistics fixtures included in original]
    // [See full file for 200+ lines of JSON fixtures]
}

// MARK: - Model Factories

enum TestData {
    static let testUUID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
    static let testUUID2 = UUID(uuidString: "660e8400-e29b-41d4-a716-446655440001")!
    static let testUUID3 = UUID(uuidString: "770e8400-e29b-41d4-a716-446655440002")!
    static let testBaseURL = URL(string: "https://print.example.com")!

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func decodePrinter(from json: String = TestJSON.printer) throws -> Printer {
        try decoder.decode(Printer.self, from: json.data(using: .utf8)!)
    }

    static func decodePrintJob(from json: String = TestJSON.printJob) throws -> PrintJob {
        try decoder.decode(PrintJob.self, from: json.data(using: .utf8)!)
    }

    static func decodeLocation(from json: String = TestJSON.location) throws -> Location {
        try decoder.decode(Location.self, from: json.data(using: .utf8)!)
    }

    static func decodeQueuedPrintJobResponse(from json: String) throws -> QueuedPrintJobResponse {
        try decoder.decode(QueuedPrintJobResponse.self, from: json.data(using: .utf8)!)
    }

    static func decodeAppNotification(from json: String) throws -> AppNotification {
        try decoder.decode(AppNotification.self, from: json.data(using: .utf8)!)
    }

    static func decodeStatisticsSummary(from json: String = TestJSON.statisticsSummary) throws -> StatisticsSummary {
        try decoder.decode(StatisticsSummary.self, from: json.data(using: .utf8)!)
    }

    static func decodeAuthResponse(from json: String = TestJSON.authResponseSuccess) throws -> AuthResponse {
        try decoder.decode(AuthResponse.self, from: json.data(using: .utf8)!)
    }

    static func decodeUser(from json: String = TestJSON.userDTO) throws -> UserDTO {
        try decoder.decode(UserDTO.self, from: json.data(using: .utf8)!)
    }

    static func httpResponse(url: URL? = nil, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url ?? testBaseURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
```

**Key Fixture Patterns:**
- ✅ Enum-based namespace for JSON strings (TestJSON, TestData)
- ✅ Dual-level fixtures: Complete and Minimal variants
- ✅ Composite fixtures: Arrays and nested structures
- ✅ Factory functions with default parameters
- ✅ ISO8601 date decoding strategy for consistent date handling
- ✅ Predefined test constants (UUIDs, URLs)
- ✅ HTTPURLResponse factory for network simulation
- ✅ JSON strings match backend DTO structures exactly
- ✅ Multiple scenarios (Success, Failure, Queued, Completed, etc.)

---

### 1.4 TestProtocols.swift — Protocol Definition Pattern
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/Mocks/TestProtocols.swift`

```swift
import Foundation
@testable import PrintFarmer

// MARK: - Test-only Protocol
// Auth has no production protocol yet. Define one here for mock testing.
// The production AuthService is an actor — this lets us test auth flows
// with a mock without hitting Keychain or network.

protocol AuthServiceProtocol: Sendable {
    func login(serverURL: String, username: String, password: String) async throws -> AuthResponse
    func logout() async
    func restoreSession() async -> UserDTO?
    func currentUser() async throws -> UserDTO
    var isAuthenticated: Bool { get async }
}

// NOTE: PrinterServiceProtocol, JobServiceProtocol, NotificationServiceProtocol,
// and StatisticsServiceProtocol are now defined in production code
// at PrintFarmer/Protocols/. Do NOT redefine them here.
```

**Key Protocol Patterns:**
- ✅ Test-only protocols for services that don't have production protocols yet
- ✅ `Sendable` conformance for actor compatibility
- ✅ `async throws` methods for network operations
- ✅ `async` computed properties for state access
- ✅ Clear documentation about production vs. test-only protocols
- ✅ Coordination with production protocol files (cross-reference notes)

---

## 2. SOURCE CODE PATTERNS

### 2.1 Model Structure — Spoolman Models
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/Models/FilamentModels.swift`

```swift
import Foundation

// MARK: - Spoolman Spool (matches SpoolmanSpoolDto)

struct SpoolmanSpool: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let material: String
    let colorHex: String?
    let inUse: Bool
    let filamentName: String?
    let vendor: String?
    let registeredAt: String?
    let firstUsedAt: String?
    let lastUsedAt: String?

    // Weight & length
    let remainingWeightG: Double?
    let initialWeightG: Double?
    let usedWeightG: Double?
    let spoolWeightG: Double?
    let remainingLengthMm: Double?
    let usedLengthMm: Double?

    // Metadata
    let location: String?
    let lotNumber: String?
    let archived: Bool?
    let price: Double?
    let comment: String?

    // Computed by backend
    let usedPercent: Double?
    let remainingPercent: Double?
}

// MARK: - Spoolman Filament (matches SpoolmanFilamentDto)

struct SpoolmanFilament: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let material: String?
    let colorHex: String?
    let vendor: String?
    let density: Double?
    let diameter: Double?
    let weight: Double?
    let spoolWeight: Double?
    let price: Double?
    let settingsExtruderTemp: Int?
    let settingsBedTemp: Int?
    let articleNumber: String?
    let comment: String?
    let multiColorHexes: String?
    let externalId: String?
}

// MARK: - Spoolman Vendor (matches SpoolmanVendorDto)

struct SpoolmanVendor: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let externalId: String?
}

// MARK: - Spoolman Material (matches SpoolmanMaterialDto)

struct SpoolmanMaterial: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let density: Double?
    let colorHex: String?
}

// MARK: - Paged Result (matches SpoolmanPagedResult<T>)

struct SpoolmanPagedResult<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let totalCount: Int
}

// MARK: - Spool Request (matches SpoolmanSpoolRequest — create/update)

struct SpoolmanSpoolRequest: Codable, Sendable {
    var filamentId: Int?
    var remainingWeight: Double?
    var initialWeight: Double?
    var spoolWeight: Double?
    var location: String?
    var lotNumber: String?
    var price: Double?
    var comment: String?
    var archived: Bool?
}

// MARK: - Set Active Spool Request (matches SetActiveSpoolRequest)

struct SetActiveSpoolRequest: Codable, Sendable {
    let spoolId: Int?
}
```

**Key Model Patterns:**
- ✅ `Codable` for JSON serialization
- ✅ `Identifiable` with `Int` id for list identification
- ✅ `Sendable` for actor/async compatibility
- ✅ Optional fields for API flexibility
- ✅ Commented organization by functional group
- ✅ Generic `SpoolmanPagedResult<T>` for pagination
- ✅ Separate Request model (SpoolmanSpoolRequest) for mutations
- ✅ Names match backend DTOs exactly (e.g., SpoolmanSpoolDto → SpoolmanSpool)
- ✅ Computed properties from backend (usedPercent, remainingPercent)

---

### 2.2 Service Protocol — SpoolServiceProtocol
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/Protocols/SpoolServiceProtocol.swift`

```swift
import Foundation

// MARK: - Spool Service Protocol

/// Contract for Spoolman spool operations. Lambert implements the concrete service;
/// Ripley's ViewModels depend only on this protocol.
protocol SpoolServiceProtocol: Sendable {
    func listSpools(limit: Int, offset: Int, search: String?, material: String?, vendor: String?) async throws -> SpoolmanPagedResult<SpoolmanSpool>
    func createSpool(_ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool
    func updateSpool(id: Int, _ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool
    func deleteSpool(id: Int) async throws
    func listFilaments() async throws -> [SpoolmanFilament]
    func listVendors() async throws -> [SpoolmanVendor]
    func listMaterials() async throws -> [SpoolmanMaterial]
}

// Convenience overloads
extension SpoolServiceProtocol {
    func listSpools(limit: Int = 50, offset: Int = 0) async throws -> SpoolmanPagedResult<SpoolmanSpool> {
        try await listSpools(limit: limit, offset: offset, search: nil, material: nil, vendor: nil)
    }
}
```

**Key Service Protocol Patterns:**
- ✅ `Sendable` conformance for actor safety
- ✅ `async throws` for network operations
- ✅ Clear documentation (Lambert/Ripley reference for context)
- ✅ CRUD operations: Create, Read (list + filter), Update, Delete
- ✅ Related data endpoints: Filaments, Vendors, Materials
- ✅ Extension with default parameters for convenience
- ✅ Pagination support: limit + offset
- ✅ Filtering support: search, material, vendor

---

### 2.3 Service Implementation — SpoolService
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/Services/SpoolService.swift`

```swift
import Foundation

// MARK: - Spool Service

actor SpoolService: SpoolServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listSpools(limit: Int = 50, offset: Int = 0, search: String? = nil, material: String? = nil, vendor: String? = nil) async throws -> SpoolmanPagedResult<SpoolmanSpool> {
        var params: [String] = []
        params.append("limit=\(limit)")
        params.append("offset=\(offset)")
        if let search { params.append("search=\(search)") }
        if let material { params.append("material=\(material)") }
        if let vendor { params.append("vendor=\(vendor)") }
        let query = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return try await apiClient.get("/api/spoolman/spools\(query)")
    }

    func createSpool(_ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool {
        try await apiClient.post("/api/spoolman/spools", body: request)
    }

    func updateSpool(id: Int, _ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool {
        try await apiClient.patch("/api/spoolman/spools/\(id)", body: request)
    }

    func deleteSpool(id: Int) async throws {
        try await apiClient.delete("/api/spoolman/spools/\(id)")
    }

    func listFilaments() async throws -> [SpoolmanFilament] {
        try await apiClient.get("/api/spoolman/filaments")
    }

    func listVendors() async throws -> [SpoolmanVendor] {
        try await apiClient.get("/api/spoolman/vendors")
    }

    func listMaterials() async throws -> [SpoolmanMaterial] {
        try await apiClient.get("/api/spoolman/materials")
    }
}
```

**Key Service Implementation Patterns:**
- ✅ `actor` keyword for thread-safe concurrent access
- ✅ Single responsibility: Wraps APIClient for Spoolman endpoints
- ✅ Constructor injection of APIClient dependency
- ✅ Protocol conformance with all required methods
- ✅ Query string building for filter parameters
- ✅ RESTful API: GET (list), POST (create), PATCH (update), DELETE
- ✅ Generic APIClient methods handle JSON serialization
- ✅ Standard endpoint paths: `/api/spoolman/{resource}`

---

### 2.4 ViewModel — SpoolPickerViewModel
**File:** `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/ViewModels/SpoolPickerViewModel.swift`

```swift
import Foundation
import os

@MainActor @Observable
final class SpoolPickerViewModel {
    var spools: [SpoolmanSpool] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "SpoolPicker")
    private var spoolService: (any SpoolServiceProtocol)?

    func configure(spoolService: any SpoolServiceProtocol) {
        self.spoolService = spoolService
    }

    var filteredSpools: [SpoolmanSpool] {
        guard !searchText.isEmpty else { return spools }
        let query = searchText.lowercased()
        return spools.filter { spool in
            spool.material.lowercased().contains(query)
            || (spool.filamentName?.lowercased().contains(query) ?? false)
            || (spool.vendor?.lowercased().contains(query) ?? false)
            || spool.name.lowercased().contains(query)
        }
    }

    func loadSpools() async {
        guard let spoolService else {
            errorMessage = "Spool service not available"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await spoolService.listSpools(limit: 200, offset: 0)
            spools = result.items.filter { !($0.archived ?? false) }
        } catch {
            logger.warning("Failed to load spools: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
```

**Key ViewModel Patterns:**
- ✅ `@MainActor` for main thread UI updates
- ✅ `@Observable` macro for SwiftUI reactivity (iOS 17+)
- ✅ State properties: spools, searchText, isLoading, errorMessage
- ✅ Protocol-based dependency injection via `configure()`
- ✅ Logger integration for debugging
- ✅ Computed property for filtering (filteredSpools)
- ✅ Async loading with error handling
- ✅ State management during async operations (isLoading)
- ✅ Data filtering (archived spools removed)
- ✅ Guard against unconfigured service
- ✅ Supports searching by: material, filament name, vendor, spool name

---

## 3. ARCHITECTURE SUMMARY

### Test Architecture
```
PrintFarmerTests/
├── Mocks/
│   ├── MockSpoolService.swift        ← Implements SpoolServiceProtocol
│   ├── TestProtocols.swift           ← Test-only protocols (AuthServiceProtocol)
│   └── [other mocks for Printer, Job, etc.]
├── Helpers/
│   └── TestFixtures.swift            ← JSON + Factory enums
├── ViewModels/
│   ├── PrinterListViewModelTests.swift
│   └── [other ViewModel tests]
└── Services/
    └── [Service tests]
```

### Service Architecture
```
PrintFarmer/
├── Protocols/
│   ├── SpoolServiceProtocol.swift
│   ├── PrinterServiceProtocol.swift
│   ├── JobServiceProtocol.swift
│   └── [other service protocols]
├── Services/
│   ├── SpoolService.swift            ← Actor implementing SpoolServiceProtocol
│   ├── PrinterService.swift
│   ├── JobService.swift
│   ├── APIClient.swift               ← Core HTTP client
│   └── [other services]
├── Models/
│   ├── FilamentModels.swift          ← Spoolman models
│   ├── Models.swift                  ← Core DTOs
│   └── RequestModels.swift           ← Request bodies
└── ViewModels/
    ├── SpoolPickerViewModel.swift    ← Uses SpoolServiceProtocol
    └── [other ViewModels]
```

### Dependency Flow
```
ViewModel (@Observable, @MainActor)
    ↓ (uses protocol)
SpoolServiceProtocol
    ↓ (implemented by)
SpoolService (actor)
    ↓ (uses)
APIClient
    ↓ (serializes)
SpoolmanSpool (Codable, Sendable)
```

---

## 4. TESTING BEST PRACTICES IDENTIFIED

1. **Mock Pattern**: State + Call Tracking + Error Injection + Reset
2. **ViewModel Tests**: @MainActor + Dependency Injection + Grouped test sections
3. **Fixtures**: Enum namespaces + JSON strings + Factory functions with defaults
4. **Service Design**: Actor-based + Protocol-first + Generic error handling
5. **Concurrency**: Async/await throughout + Sendable conformance
6. **State Management**: Observable macro + Computed properties for filtering

---

## 5. KEY FILES REFERENCE

| File | Purpose | Path |
|------|---------|------|
| MockSpoolService.swift | Mock for SpoolServiceProtocol | PrintFarmerTests/Mocks/ |
| PrinterListViewModelTests.swift | ViewModel test example | PrintFarmerTests/ViewModels/ |
| TestFixtures.swift | JSON + Factory fixtures | PrintFarmerTests/Helpers/ |
| TestProtocols.swift | Test-only protocols | PrintFarmerTests/Mocks/ |
| SpoolServiceProtocol.swift | Service contract | PrintFarmer/Protocols/ |
| SpoolService.swift | Service implementation (actor) | PrintFarmer/Services/ |
| SpoolPickerViewModel.swift | ViewModel using protocol DI | PrintFarmer/ViewModels/ |
| FilamentModels.swift | Spoolman data models | PrintFarmer/Models/ |

