import Foundation

// MARK: - AutoDispatch Status

struct AutoDispatchStatus: Codable, Sendable {
    let printerId: UUID
    let autoDispatchEnabled: Bool
    let state: String
    let queuedJobCount: Int

    private enum CodingKeys: String, CodingKey {
        case printerId
        case autoDispatchEnabled = "autoPrintEnabled"
        case state
        case queuedJobCount
    }

    init(printerId: UUID, autoDispatchEnabled: Bool, state: String, queuedJobCount: Int) {
        self.printerId = printerId
        self.autoDispatchEnabled = autoDispatchEnabled
        self.state = state
        self.queuedJobCount = queuedJobCount
    }
}

// MARK: - AutoDispatch Ready Result

struct AutoDispatchReadyResult: Codable, Sendable {
    let status: AutoDispatchStatus
    let nextJob: AutoDispatchNextJob?
    let filamentCheck: FilamentCheckResult?
}

// MARK: - AutoDispatch Next Job

struct AutoDispatchNextJob: Codable, Sendable, Identifiable {
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

struct SetAutoDispatchEnabledRequest: Encodable, Sendable {
    let enabled: Bool
}
