import Foundation

// MARK: - Enums

enum PrinterBackend: Int, Codable, Sendable {
    case unknown = 0
    case moonraker = 1
    case prusaLink = 2
    case sdcp = 3
    case octoPrint = 4
    case flashForge = 5
}

enum PrintJobStatus: Int, Codable, Sendable {
    case queued = 0
    case assigned = 1
    case starting = 2
    case printing = 3
    case paused = 4
    case completed = 5
    case failed = 6
    case cancelled = 7
}

enum PrintJobPriority: Int, Codable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
}

enum AutoPrintState: Int, Codable, Sendable {
    case none = 0
    case pendingReady = 1
    case ready = 2
}

// MARK: - Printer

struct Printer: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let notes: String?
    let serverUrl: String
    let originalServerUrl: String?
    let backendPort: Int
    let frontendPort: Int?
    let backend: PrinterBackend
    let apiKey: String?
    let username: String?
    let password: String?
    let cameraStreamUrl: String?
    let cameraSnapshotUrl: String?
    let manufacturerId: UUID?
    let manufacturerName: String?
    let modelId: UUID?
    let modelName: String?
    let locationId: UUID?

    // Status
    let isOnline: Bool
    let state: String?
    let progress: Double?
    let jobName: String?
    let isAvailable: Bool
    let inMaintenance: Bool
    let isEnabled: Bool

    // Hardware
    let maxBuildVolumeX: Double?
    let maxBuildVolumeY: Double?
    let maxBuildVolumeZ: Double?
    let hasHeatedBed: Bool
    let hasEnclosure: Bool
    let multiMaterial: Bool
    let supportsAutoLeveling: Bool
    let maxPrintSpeed: Int?
    let maxBedTemp: Int?

    // Live telemetry
    let hotendTemp: Double?
    let bedTemp: Double?
    let hotendTarget: Double?
    let bedTarget: Double?
    let x: Double?
    let y: Double?
    let z: Double?

    // Metadata
    let thumbnailUrl: String?
    let spoolInfo: PrinterSpoolInfo?
    let currentMaterial: String?
    let currentSpoolId: Int?
    let autoPrintEnabled: Bool
    let autoPrintState: AutoPrintState
    let backendUrl: String?
    let frontendUrl: String?
    let location: LocationSummary?
}

struct PrinterSpoolInfo: Codable, Sendable {
    let hasActiveSpool: Bool
    let activeSpoolId: Int?
    let spoolName: String?
    let material: String?
    let colorHex: String?
    let filamentName: String?
    let vendor: String?
    let remainingWeightG: Double?
    let spoolInUse: Bool?
}

// MARK: - Print Job

struct PrintJob: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let status: PrintJobStatus
    let priority: Int
    let queuePosition: Int
    let gcodeFileId: UUID?
    let gcodeFileName: String
    let assignedPrinterId: UUID?
    let assignedPrinterName: String?
    let createdAt: Date
    let updatedAt: Date
    let queuedAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let estimatedPrintTime: TimeInterval?
    let actualPrintTime: TimeInterval?
    let estimatedFilamentUsage: Double?
    let actualFilamentUsage: Double?
    let estimatedCost: Decimal?
    let actualCost: Decimal?
    let failureReason: String?
    let hotendTemperature: Double?
    let bedTemperature: Double?
    let progressPercentage: Double?
    let currentState: String?
    let requiredCapabilities: [String]?
    let autoAssign: Bool
    let preferredPrinterIds: [UUID]?
    let excludedPrinterIds: [UUID]?
    let copies: Int
    let completedCopies: Int
    let projectId: UUID?
    let projectName: String?
    let filamentName: String?
    let filamentVendor: String?
    let filamentColor: String?

    var remainingCopies: Int {
        max(0, copies - completedCopies)
    }

    var isMultiCopy: Bool {
        copies > 1
    }
}

// MARK: - Location

struct Location: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let printerCount: Int
    let createdAt: Date
    let modifiedAt: Date
    let isActive: Bool
}

struct LocationSummary: Codable, Sendable {
    let id: UUID
    let name: String
    let description: String?
}

// MARK: - Auth

struct LoginRequest: Codable, Sendable {
    let usernameOrEmail: String
    let password: String
    let rememberMe: Bool
}

struct LoginResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpires: Date
    let refreshTokenExpires: Date
    let user: UserDTO
}

struct UserDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let isActive: Bool
    let emailConfirmed: Bool
    let lastLogin: Date?
    let createdAt: Date
    let roles: [String]
    let permissions: [String]
}
