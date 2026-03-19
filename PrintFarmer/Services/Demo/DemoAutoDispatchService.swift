import Foundation

// MARK: - Demo AutoDispatch Service

final class DemoAutoDispatchService: AutoDispatchServiceProtocol, @unchecked Sendable {

    func getAllStatus() async throws -> [AutoDispatchStatus] {
        [
            AutoDispatchStatus(printerId: DemoData.prusaMK4_1_ID, autoDispatchEnabled: true,
                               state: AutoDispatchState.ready.rawValue, queuedJobCount: 1),
            AutoDispatchStatus(printerId: DemoData.prusaMK4_2_ID, autoDispatchEnabled: true,
                               state: AutoDispatchState.ready.rawValue, queuedJobCount: 0),
            AutoDispatchStatus(printerId: DemoData.bambuX1C_ID, autoDispatchEnabled: true,
                               state: AutoDispatchState.pendingReady.rawValue, queuedJobCount: 1),
            AutoDispatchStatus(printerId: DemoData.bambuP1S_ID, autoDispatchEnabled: false,
                               state: AutoDispatchState.none.rawValue, queuedJobCount: 1),
            AutoDispatchStatus(printerId: DemoData.voron24_ID, autoDispatchEnabled: true,
                               state: AutoDispatchState.none.rawValue, queuedJobCount: 0),
            AutoDispatchStatus(printerId: DemoData.ender3V3_ID, autoDispatchEnabled: false,
                               state: AutoDispatchState.none.rawValue, queuedJobCount: 0),
        ]
    }

    func getStatus(printerId: UUID) async throws -> AutoDispatchStatus {
        let all = try await getAllStatus()
        guard let status = all.first(where: { $0.printerId == printerId }) else {
            return AutoDispatchStatus(printerId: printerId, autoDispatchEnabled: false,
                                      state: AutoDispatchState.none.rawValue, queuedJobCount: 0)
        }
        return status
    }

    func markReady(printerId: UUID) async throws -> AutoDispatchReadyResult {
        let status = AutoDispatchStatus(printerId: printerId, autoDispatchEnabled: true,
                                        state: AutoDispatchState.ready.rawValue, queuedJobCount: 1)
        let nextJob = AutoDispatchNextJob(id: DemoData.job5ID, name: "raspberry_pi_case.gcode",
                                          estimatedFilamentUsageG: 35.0, requiredMaterialType: "PLA",
                                          estimatedPrintTime: 8100)
        let filamentCheck = FilamentCheckResult(sufficient: true, remainingWeightG: 750.0,
                                                requiredWeightG: 35.0, loadedMaterial: "PLA",
                                                requiredMaterial: "PLA", materialMismatch: false,
                                                message: "Sufficient filament available")
        return AutoDispatchReadyResult(status: status, nextJob: nextJob, filamentCheck: filamentCheck)
    }

    func skip(printerId: UUID) async throws -> AutoDispatchStatus {
        AutoDispatchStatus(printerId: printerId, autoDispatchEnabled: true,
                           state: AutoDispatchState.none.rawValue, queuedJobCount: 0)
    }

    func cancel(printerId: UUID) async throws -> AutoDispatchStatus {
        AutoDispatchStatus(printerId: printerId, autoDispatchEnabled: true,
                           state: AutoDispatchState.none.rawValue, queuedJobCount: 0)
    }

    func setEnabled(printerId: UUID, request: SetAutoDispatchEnabledRequest) async throws -> AutoDispatchStatus {
        AutoDispatchStatus(printerId: printerId, autoDispatchEnabled: request.enabled,
                           state: AutoDispatchState.none.rawValue, queuedJobCount: 0)
    }
}
