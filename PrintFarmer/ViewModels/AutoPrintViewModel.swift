import Foundation
import os

@MainActor @Observable
final class AutoPrintViewModel {
    var status: AutoPrintStatus?
    var readyResult: AutoPrintReadyResult?
    var isLoading = false
    var error: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "AutoPrint")
    private var autoPrintService: (any AutoPrintServiceProtocol)?

    func configure(autoPrintService: any AutoPrintServiceProtocol) {
        self.autoPrintService = autoPrintService
    }

    func loadStatus(printerId: UUID) async {
        guard let autoPrintService else { return }
        isLoading = true
        error = nil

        do {
            status = try await autoPrintService.getStatus(printerId: printerId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func markReady(printerId: UUID) async {
        guard let autoPrintService else { return }
        do {
            readyResult = try await autoPrintService.markReady(printerId: printerId)
            await loadStatus(printerId: printerId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func skip(printerId: UUID) async {
        guard let autoPrintService else { return }
        do {
            status = try await autoPrintService.skip(printerId: printerId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleEnabled(printerId: UUID) async {
        guard let autoPrintService else { return }
        let currentlyEnabled = status?.autoPrintEnabled ?? false
        do {
            status = try await autoPrintService.setEnabled(
                printerId: printerId,
                request: SetAutoPrintEnabledRequest(enabled: !currentlyEnabled)
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Computed

    var isEnabled: Bool { status?.autoPrintEnabled ?? false }
    var currentState: String { status?.state ?? "Unknown" }
}
