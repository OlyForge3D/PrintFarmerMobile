# PFarm-iOS Testing Quick Reference Guide

## 📋 File Locations & Full Contents

### Test Files (PrintFarmerTests/)
1. **MockSpoolService.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/Mocks/MockSpoolService.swift`
   - Implements `SpoolServiceProtocol`
   - Pattern: State properties + Call tracking + Error injection + Reset method
   - 83 lines

2. **PrinterListViewModelTests.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/ViewModels/PrinterListViewModelTests.swift`
   - Tests PrinterListViewModel with MockPrinterService
   - Pattern: @MainActor + DI via configure() + Grouped test methods
   - 177 lines total, tests: Initial State, Load, Search Filtering, Status Filtering, Pull to Refresh, Not Configured

3. **TestFixtures.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/Helpers/TestFixtures.swift`
   - JSON fixtures (TestJSON enum) + Factory methods (TestData enum)
   - 497 lines: Fixtures for Printer, PrintJob, Location, Auth, Notifications, Statistics
   - Decoder setup with ISO8601 date strategy

4. **TestProtocols.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmerTests/Mocks/TestProtocols.swift`
   - Defines `AuthServiceProtocol` (test-only, production doesn't have protocol yet)
   - Pattern: Sendable + async throws methods + async computed properties
   - Cross-references production protocols in PrintFarmer/Protocols/

### Source Files (PrintFarmer/)

5. **SpoolServiceProtocol.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/Protocols/SpoolServiceProtocol.swift`
   - Service contract interface
   - 7 methods: listSpools (with search/filter), create, update, delete, listFilaments, listVendors, listMaterials
   - Extension with convenience overloads

6. **SpoolService.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/Services/SpoolService.swift`
   - Actor implementation (thread-safe concurrent access)
   - 46 lines: Wraps APIClient for Spoolman endpoints
   - RESTful: GET, POST, PATCH, DELETE

7. **FilamentModels.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/Models/FilamentModels.swift`
   - 103 lines: SpoolmanSpool, SpoolmanFilament, SpoolmanVendor, SpoolmanMaterial
   - All models: Codable + Identifiable (Int id) + Sendable
   - SpoolmanPagedResult<T>, SpoolmanSpoolRequest, SetActiveSpoolRequest

8. **SpoolPickerViewModel.swift** — `/Users/jpapiez/s/PFarm-Ios/PrintFarmer/ViewModels/SpoolPickerViewModel.swift`
   - @MainActor @Observable
   - State: spools, searchText, isLoading, errorMessage
   - Async loadSpools() with error handling
   - Computed filteredSpools (searches: material, filamentName, vendor, name)
   - 48 lines

---

## 🎯 Key Patterns by Layer

### Mock Pattern
```swift
final class MockSpoolService: SpoolServiceProtocol, @unchecked Sendable {
    // 1. State for returns
    var spoolsPageToReturn: SpoolmanPagedResult<SpoolmanSpool> = ...
    var spoolToReturn: SpoolmanSpool?
    var errorToThrow: Error?
    
    // 2. Call tracking
    var listSpoolsCalled = false
    var listSpoolsArgs: (limit: Int, offset: Int, search: String?, material: String?, vendor: String?)?
    
    // 3. Implement protocol methods
    func listSpools(...) async throws -> ... {
        listSpoolsCalled = true
        listSpoolsArgs = (limit, offset, search, material, vendor)
        if let error = errorToThrow { throw error }
        return spoolsPageToReturn
    }
    
    // 4. Reset method
    func reset() { /* clear all state */ }
}
```

### ViewModel Test Pattern
```swift
@MainActor
final class PrinterListViewModelTests: XCTestCase {
    private var mockService: MockPrinterService!
    private var viewModel: PrinterListViewModel!
    
    override func setUp() {
        mockService = MockPrinterService()
        viewModel = PrinterListViewModel()
        viewModel.configure(printerService: mockService)
    }
    
    // Tests grouped by MARK sections:
    // - MARK: - Initial State
    // - MARK: - Load Printers
    // - MARK: - Search Filtering
    // - MARK: - Status Filtering
    // - MARK: - Pull to Refresh
    // - MARK: - Not Configured
    
    func testLoadPrintersSuccessPopulatesList() async throws {
        mockService.printersToReturn = [printer]
        await viewModel.loadPrinters()
        XCTAssertEqual(viewModel.printers.count, 1)
    }
}
```

### Service Protocol + Implementation
```swift
// Protocol
protocol SpoolServiceProtocol: Sendable {
    func listSpools(limit: Int, offset: Int, search: String?, material: String?, vendor: String?) async throws -> SpoolmanPagedResult<SpoolmanSpool>
    // ... other methods
}

// Implementation (Actor for thread safety)
actor SpoolService: SpoolServiceProtocol {
    private let apiClient: APIClient
    
    func listSpools(...) async throws -> ... {
        var params: [String] = []
        params.append("limit=\(limit)")
        // ... build query
        let query = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return try await apiClient.get("/api/spoolman/spools\(query)")
    }
}
```

### ViewModel Pattern (@Observable)
```swift
@MainActor @Observable
final class SpoolPickerViewModel {
    var spools: [SpoolmanSpool] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?
    
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
        guard let spoolService else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await spoolService.listSpools(limit: 200, offset: 0)
            spools = result.items.filter { !($0.archived ?? false) }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

### Fixture Pattern
```swift
enum TestJSON {
    static let printer = """
    { "id": "...", "name": "Prusa MK4", ... }
    """
    static let printerMinimal = """
    { "id": "...", "name": "Ender 3", ... }
    """
}

enum TestData {
    static let testUUID = UUID(uuidString: "...")!
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    static func decodePrinter(from json: String = TestJSON.printer) throws -> Printer {
        try decoder.decode(Printer.self, from: json.data(using: .utf8)!)
    }
}
```

---

## 🔗 Dependencies & DI Flow

```
SpoolPickerViewModel
    ↓ configure(spoolService:)
SpoolServiceProtocol (protocol)
    ↓ implemented by
SpoolService (actor)
    ↓ injected: APIClient
APIClient
    ↓ serializes/deserializes
SpoolmanSpool (Codable, Identifiable, Sendable)
SpoolmanPagedResult<SpoolmanSpool>
```

### In Tests:
```
SpoolPickerViewModel
    ↓ configure(spoolService:)
MockSpoolService (implements protocol)
    ↓ returns from state
SpoolmanSpool (from TestData.decodePrinter() fixtures)
```

---

## ✅ Testing Checklist

- [ ] Mock implements the protocol with @unchecked Sendable
- [ ] Call tracking for assertions (was method called? with what args?)
- [ ] Error injection path (errorToThrow property)
- [ ] Reset method for test isolation
- [ ] @MainActor on ViewModel tests
- [ ] Dependency injection via configure()
- [ ] setUp() creates fresh instances
- [ ] tearDown() cleans up
- [ ] Async test methods use `async throws`
- [ ] Tests grouped by MARK sections
- [ ] JSON fixtures cover multiple scenarios (complete, minimal, error cases)
- [ ] Factory methods with default parameters
- [ ] ISO8601 date decoder configured
- [ ] Error path testing
- [ ] State mutation testing
- [ ] Edge case testing (empty, unconfigured)
- [ ] Computed property testing (filtering, searching)

---

## 📊 File Summary

| File | Lines | Purpose |
|------|-------|---------|
| MockSpoolService.swift | 83 | Mock implementation pattern |
| PrinterListViewModelTests.swift | 177 | ViewModel test pattern example |
| TestFixtures.swift | 497 | JSON fixtures + factories |
| TestProtocols.swift | 20 | Test-only protocol definitions |
| SpoolServiceProtocol.swift | 23 | Service contract interface |
| SpoolService.swift | 46 | Service actor implementation |
| FilamentModels.swift | 103 | Data models (Spool, Filament, etc.) |
| SpoolPickerViewModel.swift | 48 | ViewModel implementation |

---

## 🚀 Key Takeaways

1. **Mock Mojo**: State + Tracking + Errors + Reset = Complete test control
2. **ViewModel Tests**: Group tests by functionality (Load, Filter, Refresh, etc.)
3. **Fixtures**: Enum namespaces with JSON strings + factory methods
4. **DI Pattern**: configure() method for runtime injection
5. **Async/Await**: Fully async-based testing with proper error paths
6. **Concurrency**: Actor-based services + Sendable models
7. **State Management**: @Observable + computed properties for reactivity

