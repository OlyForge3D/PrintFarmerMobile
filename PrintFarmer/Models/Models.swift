import Foundation

// MARK: - Enums

enum PrinterBackend: String, Codable, Sendable {
    case unknown = "Unknown"
    case moonraker = "Moonraker"
    case prusaLink = "PrusaLink"
    case sdcp = "SDCP"
    case octoPrint = "OctoPrint"
    case flashForge = "FlashForge"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self),
           let value = Self(rawValue: str) {
            self = value
        } else if let num = try? container.decode(Int.self) {
            switch num {
            case 0: self = .unknown
            case 1: self = .moonraker
            case 2: self = .prusaLink
            case 3: self = .sdcp
            case 4: self = .octoPrint
            case 5: self = .flashForge
            default: self = .unknown
            }
        } else {
            self = .unknown
        }
    }
}

enum MotionType: String, Codable, Sendable {
    case cartesian = "Cartesian"
    case coreXY = "CoreXY"
    case delta = "Delta"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self),
           let value = Self(rawValue: str) {
            self = value
        } else if let num = try? container.decode(Int.self) {
            switch num {
            case 0: self = .cartesian
            case 1: self = .coreXY
            case 2: self = .delta
            default: self = .unknown
            }
        } else {
            self = .unknown
        }
    }
}

enum PrintJobStatus: String, Codable, Sendable {
    case queued = "Queued"
    case assigned = "Assigned"
    case starting = "Starting"
    case printing = "Printing"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self),
           let value = Self(rawValue: str) {
            self = value
        } else if let num = try? container.decode(Int.self) {
            switch num {
            case 0: self = .queued
            case 1: self = .assigned
            case 2: self = .starting
            case 3: self = .printing
            case 4: self = .paused
            case 5: self = .completed
            case 6: self = .failed
            case 7: self = .cancelled
            default: self = .queued
            }
        } else {
            self = .queued
        }
    }
}

enum PrintJobPriority: String, Codable, Sendable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case urgent = "Urgent"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self),
           let value = Self(rawValue: str) {
            self = value
        } else if let num = try? container.decode(Int.self) {
            switch num {
            case 0: self = .low
            case 1: self = .normal
            case 2: self = .high
            case 3: self = .urgent
            default: self = .normal
            }
        } else {
            self = .normal
        }
    }

    /// Maps the backend integer priority value to the enum.
    static func from(intValue: Int) -> PrintJobPriority? {
        switch intValue {
        case 0: .low
        case 1: .normal
        case 2: .high
        case 3: .urgent
        default: nil
        }
    }
}

enum AutoPrintState: String, Codable, Sendable {
    case none = "None"
    case pendingReady = "PendingReady"
    case ready = "Ready"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self),
           let value = Self(rawValue: str) {
            self = value
        } else if let num = try? container.decode(Int.self) {
            switch num {
            case 0: self = .none
            case 1: self = .pendingReady
            case 2: self = .ready
            default: self = .none
            }
        } else {
            self = .none
        }
    }
}

enum NotificationType: String, Codable, Sendable {
    case jobStarted = "JobStarted"
    case jobCompleted = "JobCompleted"
    case jobFailed = "JobFailed"
    case jobPaused = "JobPaused"
    case jobResumed = "JobResumed"
    case queueAlert = "QueueAlert"
    case systemAlert = "SystemAlert"
}

enum NotificationFrequency: String, Codable, Sendable {
    case realTime = "RealTime"
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case never = "Never"
}

// MARK: - Printer (matches CompletePrinterDto from backend)

struct Printer: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let notes: String?

    // Catalog
    let manufacturerId: UUID?
    let manufacturerName: String?
    let modelId: UUID?
    let modelName: String?
    let motionType: MotionType?

    // Config
    let backend: PrinterBackend
    let apiKey: String?
    let originalServerUrl: String?
    let backendPort: Int
    let frontendPort: Int?
    let inMaintenance: Bool
    let isEnabled: Bool

    // Live status (from SignalR cache)
    let isOnline: Bool
    let state: String?
    let progress: Double?
    let jobName: String?
    let thumbnailUrl: String?
    let cameraStreamUrl: String?

    // Telemetry
    let x: Double?
    let y: Double?
    let z: Double?
    let hotendTemp: Double?
    let bedTemp: Double?
    let hotendTarget: Double?
    let bedTarget: Double?
    let homedAxes: String?

    // Metadata
    let spoolInfo: PrinterSpoolInfo?
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

// MARK: - Printer Status Detail (matches PrinterStatusDto)

struct PrinterStatusDetail: Codable, Sendable {
    let id: UUID
    let isOnline: Bool
    let state: String?
    let progress: Double?
    let jobName: String?
    let thumbnailUrl: String?
    let cameraStreamUrl: String?
    let cameraSnapshotUrl: String?
    let x: Double?
    let y: Double?
    let z: Double?
    let hotendTemp: Double?
    let bedTemp: Double?
    let hotendTarget: Double?
    let bedTarget: Double?
    let spoolInfo: PrinterSpoolInfo?
    let mmuStatus: MmuStatus?
}

// MARK: - MMU Status (matches MmuStatusDto)

struct MmuStatus: Codable, Sendable {
    let enabled: Bool
    let isHomed: Bool
    let activeTool: Int
    let activeGate: Int
    let filamentState: String?
    let action: String?
    let numGates: Int
    let hasBypass: Bool
    let endlessSpool: Bool
    let clogDetection: Bool
    let gates: [MmuGate]
    let mmuType: String
}

struct MmuGate: Codable, Sendable {
    let index: Int
    let status: Int
    let material: String?
    let color: String?
    let filamentName: String?
    let spoolId: Int
    let name: String?
}

// MARK: - Print Job Status Info (matches PrintJobStatusDto)

struct PrintJobStatusInfo: Codable, Sendable {
    let state: String?
    let progress: Double?
    let jobName: String?
    let thumbnailUrl: String?
    let error: String?
}

// MARK: - Command Result (matches backend CommandResult)

struct CommandResult: Codable, Sendable {
    let success: Bool
    let message: String?
}

// MARK: - Print Job (matches JobQueuePrintJobDto)

struct PrintJob: Codable, Identifiable, Sendable {
    let id: UUID
    let status: PrintJobStatus?
    let priority: Int
    let queuePosition: Int
    let gcodeFileId: UUID?
    let gcodeFileName: String
    let assignedPrinterId: UUID?
    let assignedPrinterName: String?
    let createdAt: Date
    let updatedAt: Date
    let actualStartTime: Date?
    let actualEndTime: Date?
    let estimatedPrintTime: String?
    let actualPrintTime: String?
    let estimatedFilamentUsage: Double?
    let actualFilamentUsage: Double?
    let estimatedCost: Decimal?
    let actualCost: Decimal?
    let failureReason: String?
    let requiredNozzleDiameter: Double?
    let requiredMaterialType: String?
    let spoolmanFilamentId: Int?
    let filamentName: String?
    let filamentVendor: String?
    let filamentColor: String?
    let copies: Int
    let completedCopies: Int
    let remainingCopies: Int
    let projectFileId: UUID?

    var name: String { gcodeFileName }

    var isMultiCopy: Bool {
        copies > 1
    }
}

// MARK: - Queue Overview (matches QueueOverviewDto)

struct QueueOverview: Codable, Identifiable, Sendable {
    let printerId: UUID
    let printerName: String
    let printerModel: String
    let modelAliases: [String]?
    let isAvailable: Bool
    let queuedJobsCount: Int
    let currentJobId: UUID?
    let currentJobName: String?
    let estimatedCompletionTime: Date?
    let nozzleDiameter: Double?
    let supportedMaterials: [String]?

    var id: UUID { printerId }
}

// MARK: - Statistics Summary (matches StatisticsSummaryDto)

struct StatisticsSummary: Codable, Sendable {
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let cancelledJobs: Int
    let successRate: Double
    let totalCost: Decimal
    let totalFilamentGrams: Double
    let totalPrintHours: Double
}

// MARK: - App Notification (matches NotificationDto from backend)

struct AppNotification: Codable, Identifiable, Sendable {
    let id: String
    let userId: UUID
    let jobId: UUID?
    let type: NotificationType
    let subject: String
    let body: String
    let isRead: Bool
    let createdAt: Date
    let readAt: Date?
    let expiresAt: Date?
}

struct UnreadCountResponse: Codable, Sendable {
    let unreadCount: Int
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

// MARK: - Auth (matches AuthenticationResult from backend)

struct LoginRequest: Codable, Sendable {
    let usernameOrEmail: String
    let password: String
    let rememberMe: Bool
}

struct AuthResponse: Codable, Sendable {
    let success: Bool
    let token: String?
    let expiresAt: Date?
    let user: UserDTO?
    let error: String?
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
