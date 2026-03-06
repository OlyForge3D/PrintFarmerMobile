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
        "motionType": 0,
        "backend": 1,
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
        "backend": 1,
        "backendPort": 7125,
        "inMaintenance": false,
        "isEnabled": true,
        "isOnline": false
    }
    """

    static let printerArray = "[\(printer), \(printerMinimal)]"

    // MARK: PrintJob (JobQueuePrintJobDto)

    static let printJob = """
    {
        "id": "770e8400-e29b-41d4-a716-446655440002",
        "name": "Benchy",
        "status": 3,
        "priority": 1,
        "queuePosition": 1,
        "gcodeFileId": "880e8400-e29b-41d4-a716-446655440003",
        "gcodeFileName": "benchy.gcode",
        "assignedPrinterId": "550e8400-e29b-41d4-a716-446655440000",
        "assignedPrinterName": "Prusa MK4",
        "createdAt": "2025-07-17T10:00:00Z",
        "updatedAt": "2025-07-17T10:30:00Z",
        "queuedAt": "2025-07-17T10:00:00Z",
        "startedAt": "2025-07-17T10:15:00Z",
        "estimatedPrintTime": 3600.0,
        "estimatedFilamentUsage": 15.5,
        "estimatedCost": 2.50,
        "hotendTemperature": 215.0,
        "bedTemperature": 60.0,
        "progressPercentage": 45.0,
        "currentState": "printing",
        "autoAssign": true,
        "copies": 3,
        "completedCopies": 1,
        "filamentName": "Prusament PLA",
        "filamentVendor": "Prusa Research",
        "filamentColor": "#000000"
    }
    """

    static let printJobQueued = """
    {
        "id": "990e8400-e29b-41d4-a716-446655440004",
        "name": "Phone Case",
        "status": 0,
        "priority": 2,
        "queuePosition": 2,
        "gcodeFileName": "phone_case.gcode",
        "createdAt": "2025-07-17T09:00:00Z",
        "updatedAt": "2025-07-17T09:00:00Z",
        "queuedAt": "2025-07-17T09:00:00Z",
        "autoAssign": true,
        "copies": 1,
        "completedCopies": 0
    }
    """

    static let printJobArray = "[\(printJob), \(printJobQueued)]"

    // MARK: QueueOverview (QueueOverviewDto)

    static let queueOverview = """
    {
        "printerId": "550e8400-e29b-41d4-a716-446655440000",
        "printerName": "Prusa MK4",
        "printerModel": "MK4",
        "isAvailable": true,
        "queuedJobsCount": 2,
        "currentJobId": "770e8400-e29b-41d4-a716-446655440002",
        "currentJobName": "benchy.gcode"
    }
    """

    static let queueOverviewArray = "[\(queueOverview)]"

    // MARK: Location (LocationDto)

    static let location = """
    {
        "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
        "name": "Workshop",
        "description": "Main workshop area",
        "printerCount": 5,
        "createdAt": "2025-01-01T00:00:00Z",
        "modifiedAt": "2025-07-17T12:00:00Z",
        "isActive": true
    }
    """

    static let locationMinimal = """
    {
        "id": "d4e5f6a7-b8c9-0123-def0-234567890123",
        "name": "Garage",
        "printerCount": 0,
        "createdAt": "2025-06-01T00:00:00Z",
        "modifiedAt": "2025-06-01T00:00:00Z",
        "isActive": false
    }
    """

    // MARK: Auth

    static let authResponseSuccess = """
    {
        "success": true,
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature",
        "expiresAt": "2025-07-18T10:00:00Z",
        "user": {
            "id": "aab2c3d4-e5f6-7890-abcd-ef1234567890",
            "username": "admin",
            "email": "admin@printfarmer.local",
            "firstName": "Admin",
            "lastName": "User",
            "isActive": true,
            "emailConfirmed": true,
            "lastLogin": "2025-07-17T09:00:00Z",
            "createdAt": "2025-01-01T00:00:00Z",
            "roles": ["Admin"],
            "permissions": ["printers.manage", "jobs.manage"]
        }
    }
    """

    static let authResponseFailure = """
    {
        "success": false,
        "error": "Invalid username or password"
    }
    """

    static let userDTO = """
    {
        "id": "aab2c3d4-e5f6-7890-abcd-ef1234567890",
        "username": "admin",
        "email": "admin@printfarmer.local",
        "firstName": "Admin",
        "lastName": "User",
        "isActive": true,
        "emailConfirmed": true,
        "lastLogin": "2025-07-17T09:00:00Z",
        "createdAt": "2025-01-01T00:00:00Z",
        "roles": ["Admin"],
        "permissions": ["printers.manage"]
    }
    """

    // MARK: CommandResult

    static let commandSuccess = """
    {"success": true, "message": "Command executed"}
    """

    static let commandFailure = """
    {"success": false, "message": "Printer not ready"}
    """

    // MARK: Errors

    static let apiError = """
    {
        "title": "Validation Error",
        "status": 400,
        "detail": "The printer name is required.",
        "errors": {
            "name": ["The Name field is required."]
        }
    }
    """
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

    static func httpResponse(url: URL? = nil, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url ?? testBaseURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
