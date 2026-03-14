import Foundation
import os

@MainActor @Observable
final class AutoDispatchViewModel {
    var status: AutoDispatchStatus?
    var readyResult: AutoDispatchReadyResult?
    var isLoading = false
    var isMarkingReady = false
    var isSkipping = false
    var error: String?
    var isViewActive = true

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "AutoDispatch")
    private var autoDispatchService: (any AutoDispatchServiceProtocol)?

    func configure(autoDispatchService: any AutoDispatchServiceProtocol) {
        self.autoDispatchService = autoDispatchService
    }

    func loadStatus(printerId: UUID) async {
        guard let autoDispatchService, isViewActive else { return }
        isLoading = true
        error = nil

        do {
            status = try await autoDispatchService.getStatus(printerId: printerId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func markReady(printerId: UUID) async {
        guard let autoDispatchService else { return }
        isMarkingReady = true
        error = nil
        do {
            readyResult = try await autoDispatchService.markReady(printerId: printerId)
            // Optimistically transition away from PendingReady — the backend
            // processes the state machine asynchronously so an immediate reload
            // often still returns PendingReady even though the action succeeded.
            if let s = status {
                status = AutoDispatchStatus(
                    printerId: s.printerId,
                    autoDispatchEnabled: s.autoDispatchEnabled,
                    state: "Ready",
                    queuedJobCount: max(s.queuedJobCount - 1, 0)
                )
            }
            isMarkingReady = false
            // Reload after a short delay for the authoritative state
            try? await Task.sleep(for: .seconds(2))
            await loadStatus(printerId: printerId)
        } catch {
            self.error = error.localizedDescription
            isMarkingReady = false
        }
    }

    func skip(printerId: UUID) async {
        guard let autoDispatchService else { return }
        isSkipping = true
        error = nil
        do {
            status = try await autoDispatchService.skip(printerId: printerId)
        } catch {
            self.error = error.localizedDescription
        }
        isSkipping = false
    }

    func toggleEnabled(printerId: UUID) async {
        guard let autoDispatchService else { return }
        let currentlyEnabled = status?.autoDispatchEnabled ?? false
        do {
            status = try await autoDispatchService.setEnabled(
                printerId: printerId,
                request: SetAutoDispatchEnabledRequest(enabled: !currentlyEnabled)
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Computed

    var isEnabled: Bool { status?.autoDispatchEnabled ?? false }
    var currentState: String { status?.state ?? "Unknown" }
    
    var parsedState: AutoDispatchState? {
        guard let stateStr = status?.state else { return nil }
        return AutoDispatchState(rawValue: stateStr)
    }
}
