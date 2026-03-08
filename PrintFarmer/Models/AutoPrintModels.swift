import Foundation

// MARK: - AutoPrint Status

struct AutoPrintStatus: Codable, Sendable {
    let printerId: UUID
    let autoPrintEnabled: Bool
    let state: String
    let queuedJobCount: Int
}

// MARK: - AutoPrint Ready Result

struct AutoPrintReadyResult: Codable, Sendable {
    let status: AutoPrintStatus
    let nextJob: AutoPrintNextJob?
    let filamentCheck: FilamentCheckResult?
}

// MARK: - AutoPrint Next Job

struct AutoPrintNextJob: Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let estimatedFilamentUsageG: Double?
    let requiredMaterialType: String?
    let estimatedPrintTime: TimeInterval?
}

// MARK: - Filament Check Result

struct FilamentCheckResult: Codable, Sendable {
    let sufficient: Bool
    let remainingWeightG: Double?
    let requiredWeightG: Double?
    let loadedMaterial: String?
    let requiredMaterial: String?
    let materialMismatch: Bool
    let message: String?
}

// MARK: - Request Models

struct SetAutoPrintEnabledRequest: Encodable, Sendable {
    let enabled: Bool
}
