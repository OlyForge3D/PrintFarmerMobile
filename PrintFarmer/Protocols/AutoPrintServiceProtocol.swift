import Foundation

// MARK: - AutoPrint Service Protocol

protocol AutoPrintServiceProtocol: Sendable {
    func getAllStatus() async throws -> [AutoPrintStatus]
    func getStatus(printerId: UUID) async throws -> AutoPrintStatus
    func markReady(printerId: UUID) async throws -> AutoPrintReadyResult
    func skip(printerId: UUID) async throws -> AutoPrintStatus
    func cancel(printerId: UUID) async throws -> AutoPrintStatus
    func setEnabled(printerId: UUID, request: SetAutoPrintEnabledRequest) async throws -> AutoPrintStatus
}
