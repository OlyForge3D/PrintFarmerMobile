import XCTest
@testable import PrintFarmer

final class ModelsTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testPrinterDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Prusa MK4",
            "serverUrl": "http://192.168.1.100",
            "backendPort": 7125,
            "backend": 1,
            "isOnline": true,
            "isAvailable": true,
            "inMaintenance": false,
            "isEnabled": true,
            "hasHeatedBed": true,
            "hasEnclosure": false,
            "multiMaterial": false,
            "supportsAutoLeveling": true,
            "autoPrintEnabled": false,
            "autoPrintState": 0
        }
        """.data(using: .utf8)!

        let printer = try decoder.decode(Printer.self, from: json)
        XCTAssertEqual(printer.name, "Prusa MK4")
        XCTAssertEqual(printer.backend, .moonraker)
        XCTAssertTrue(printer.isOnline)
    }

    func testPrintJobStatusEnum() {
        XCTAssertEqual(PrintJobStatus.printing.rawValue, 3)
        XCTAssertEqual(PrintJobStatus.completed.rawValue, 5)
    }
}
