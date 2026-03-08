import Foundation

// MARK: - Maintenance Alert

struct MaintenanceAlert: Codable, Sendable, Identifiable {
    let id: UUID
    let alertType: String
    let severity: String
    let message: String
    let printerId: UUID
    let printerName: String
    let recommendedAction: String?
    let createdAt: Date
    let acknowledgedAt: Date?
    let acknowledgedBy: String?
    let resolvedAt: Date?
    let dismissedAt: Date?
}

// MARK: - Upcoming Maintenance Task

struct UpcomingMaintenanceTask: Codable, Sendable, Identifiable {
    let id: UUID
    let printerId: UUID
    let printerName: String
    let taskName: String
    let componentName: String?
    let estimatedDueDate: Date?
    let daysUntilDue: Int?
    let isOverdue: Bool
    let priority: String
}

// MARK: - Maintenance Trend

struct MaintenanceTrend: Codable, Sendable {
    let date: Date
    let printerName: String
    let component: String?
    let action: String
    let cost: Decimal
}

// MARK: - Component Lifespan

struct ComponentLifespan: Codable, Sendable {
    let component: String
    let avgLifespanHours: Double
    let replacements: Int
}

// MARK: - Maintenance Cost

struct MaintenanceCost: Codable, Sendable {
    let month: String
    let totalCost: Decimal
}

// MARK: - Printer Uptime

struct PrinterUptime: Codable, Sendable {
    let printerName: String
    let printerId: UUID
    let uptimePercent: Double
    let maintenanceCount: Int
    let totalDowntimeMinutes: Int
}

// MARK: - Fleet Printer Statistics

struct FleetPrinterStatistics: Codable, Sendable, Identifiable {
    var id: UUID { printerId }

    let printerId: UUID
    let printerName: String
    let isOnline: Bool
    let inMaintenance: Bool
    let totalPrintHours: Double
    let totalJobsCompleted: Int
    let totalJobsFailed: Int
    let daysUntilNextMaintenance: Int?
    let nextMaintenanceTask: String?

    enum CodingKeys: String, CodingKey {
        case printerId, printerName, isOnline, inMaintenance
        case totalPrintHours, totalJobsCompleted, totalJobsFailed
        case daysUntilNextMaintenance, nextMaintenanceTask
    }
}

// MARK: - Maintenance Log

struct MaintenanceLog: Codable, Sendable, Identifiable {
    let id: UUID
    let printerId: UUID
    let performedBy: String
    let action: String
    let notes: String?
    let durationMinutes: Int?
    let cost: Decimal?
    let partsReplaced: String?
    let performedAt: Date
}

// MARK: - Request Models

struct AcknowledgeAlertRequest: Encodable, Sendable {
    let acknowledgedBy: String
}

struct ResolveAlertRequest: Encodable, Sendable {
    let performedBy: String
    let notes: String?
    let durationMinutes: Int?
    let cost: Decimal?
    let partsReplaced: String?
}

struct DismissAlertRequest: Encodable, Sendable {
    let dismissedBy: String
    let reason: String?
}

// MARK: - Resolve Alert Response

struct ResolveAlertResponse: Codable, Sendable {
    let alert: MaintenanceAlert
    let maintenanceLog: MaintenanceLog?
}
