import Foundation
import SwiftUI
import os

@MainActor @Observable
final class PrinterDetailViewModel {
    var printer: Printer?
    var statusDetail: PrinterStatusDetail?
    var currentJob: PrintJobStatusInfo?
    var snapshotData: Data?
    var isLoadingSnapshot = false
    var isLoading = false
    var errorMessage: String?
    var isPerformingAction = false
    var showConfirmation = false
    var pendingAction: DestructiveAction?
    var actionError: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "PrinterDetail")

    enum DestructiveAction: Identifiable {
        case cancelPrint
        case emergencyStop

        var id: String {
            switch self {
            case .cancelPrint: "cancel"
            case .emergencyStop: "emergencyStop"
            }
        }

        var title: String {
            switch self {
            case .cancelPrint: "Cancel Print"
            case .emergencyStop: "Emergency Stop"
            }
        }

        var message: String {
            switch self {
            case .cancelPrint: "This will cancel the current print job. This action cannot be undone."
            case .emergencyStop: "This will immediately stop all printer operations. Use only in emergencies."
            }
        }
    }

    var showSpoolPicker = false
    var nfcScanError: String?
    var nfcScannedData: ScannedSpoolData?
    var showScannedDataSheet = false
    var showNFCReadyConfirmation = false

    private var nfcScanner: (any SpoolScannerProtocol)?
    private var autoPrintService: (any AutoPrintServiceProtocol)?

    let printerId: UUID
    private var printerService: (any PrinterServiceProtocol)?

    init(printerId: UUID) {
        self.printerId = printerId
    }

    func configure(printerService: any PrinterServiceProtocol) {
        self.printerService = printerService
    }

    func configureNFCScanner(_ scanner: any SpoolScannerProtocol) {
        self.nfcScanner = scanner
    }

    func configureAutoPrint(_ service: any AutoPrintServiceProtocol) {
        self.autoPrintService = service
    }

    // MARK: - NFC Printer Tag Writing

    #if canImport(UIKit)
    func writeNFCPrinterTag() {
        guard let printer else { return }
        guard let nfcService = nfcScanner as? NFCService else {
            nfcScanError = "NFC writing is not available on this device."
            return
        }
        Task {
            do {
                try await nfcService.writePrinterTag(printerId: printer.id, printerName: printer.name)
            } catch SpoolScanError.cancelled {
                // User cancelled — do nothing
            } catch {
                nfcScanError = error.localizedDescription
            }
        }
    }
    #endif

    // MARK: - Mark Ready (NFC Deep Link)

    func markPrinterReady() async {
        guard let autoPrintService else {
            actionError = "Auto-print service not available."
            return
        }
        isPerformingAction = true
        actionError = nil
        do {
            _ = try await autoPrintService.markReady(printerId: printerId)
            await loadPrinter()
        } catch {
            actionError = error.localizedDescription
        }
        isPerformingAction = false
    }

    // MARK: - Filament / Spool

    func loadFilament() {
        showSpoolPicker = true
    }

    // MARK: - NFC Scan to Load

    func handleNFCScanToLoad() {
        guard let nfcScanner, nfcScanner.isAvailable else {
            nfcScanError = "NFC scanning is not available on this device."
            return
        }

        Task {
            let result = await nfcScanner.scan()
            switch result {
            case .spoolId(let id):
                await loadSpoolById(id)
            case .newSpoolData(let data):
                nfcScannedData = data
                showScannedDataSheet = true
            case .cancelled:
                break
            case .error(let error):
                nfcScanError = error.localizedDescription
            }
        }
    }

    private func loadSpoolById(_ id: Int) async {
        guard let printerService else {
            print("⚠️ loadSpoolById: printerService is nil")
            return
        }
        isPerformingAction = true
        actionError = nil
        do {
            print("📡 loadSpoolById: printer=\(printerId) spool=\(id)")
            _ = try await printerService.setActiveSpool(printerId: printerId, spoolId: id)
            print("✅ loadSpoolById: success")
            await loadPrinter()
        } catch {
            print("❌ loadSpoolById failed: \(error)")
            actionError = error.localizedDescription
        }
        isPerformingAction = false
    }

    func ejectFilament() async {
        guard let printerService else { return }
        isPerformingAction = true
        actionError = nil
        do {
            _ = try await printerService.setActiveSpool(printerId: printerId, spoolId: nil)
            _ = try await printerService.unloadFilament(printerId: printerId)
            await loadPrinter()
        } catch {
            actionError = error.localizedDescription
        }
        isPerformingAction = false
    }

    func setActiveSpool(_ spool: SpoolmanSpool) async {
        guard let printerService else {
            print("⚠️ setActiveSpool: printerService is nil")
            return
        }
        isPerformingAction = true
        actionError = nil
        do {
            print("📡 setActiveSpool: printer=\(printerId) spool=\(spool.id)")
            _ = try await printerService.setActiveSpool(printerId: printerId, spoolId: spool.id)
            print("✅ setActiveSpool: success")
            await loadPrinter()
        } catch {
            print("❌ setActiveSpool failed: \(error)")
            actionError = error.localizedDescription
        }
        isPerformingAction = false
    }

    func loadPrinter() async {
        isLoading = true
        errorMessage = nil

        guard let printerService else {
            errorMessage = "Printer service not available"
            isLoading = false
            return
        }

        do {
            printer = try await printerService.get(id: printerId)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        do {
            statusDetail = try await printerService.getStatus(id: printerId)
        } catch {
            logger.warning("Failed to load printer status: \(error.localizedDescription)")
        }

        do {
            currentJob = try await printerService.getCurrentJob(id: printerId)
        } catch {
            logger.warning("Failed to load current job: \(error.localizedDescription)")
        }

        do {
            snapshotData = try await printerService.getSnapshot(id: printerId)
        } catch {
            logger.warning("Failed to load snapshot: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Actions

    func pausePrinter() async {
        await performAction { _ = try await $0.pause(id: self.printerId) }
    }

    func resumePrinter() async {
        await performAction { _ = try await $0.resume(id: self.printerId) }
    }

    func stopPrinter() async {
        await performAction { _ = try await $0.stop(id: self.printerId) }
    }

    func requestCancel() {
        pendingAction = .cancelPrint
        showConfirmation = true
    }

    func requestEmergencyStop() {
        pendingAction = .emergencyStop
        showConfirmation = true
    }

    func confirmAction() async {
        guard let action = pendingAction else { return }
        showConfirmation = false
        pendingAction = nil

        switch action {
        case .cancelPrint:
            await performAction { _ = try await $0.cancel(id: self.printerId) }
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
        case .emergencyStop:
            await performAction { _ = try await $0.emergencyStop(id: self.printerId) }
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }

    func toggleMaintenance() async {
        guard let printerService, let printer else { return }
        do {
            self.printer = try await printerService.setMaintenanceMode(
                id: printerId,
                inMaintenance: !printer.inMaintenance
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    func refreshSnapshot() async {
        guard let printerService else { return }
        isLoadingSnapshot = true
        do {
            snapshotData = try await printerService.getSnapshot(id: printerId)
        } catch {
            logger.warning("Failed to refresh snapshot: \(error.localizedDescription)")
        }
        isLoadingSnapshot = false
    }

    // MARK: - Computed State

    var isPrinting: Bool {
        printer?.state?.lowercased() == "printing"
    }

    var isPaused: Bool {
        printer?.state?.lowercased() == "paused"
    }

    var isIdle: Bool {
        guard let state = printer?.state?.lowercased() else { return false }
        return ["ready", "idle", "operational"].contains(state)
    }

    var isOnline: Bool {
        printer?.isOnline ?? false
    }

    // MARK: - Private

    private func performAction(_ action: @escaping (any PrinterServiceProtocol) async throws -> Void) async {
        guard let printerService else { return }
        isPerformingAction = true
        actionError = nil

        do {
            try await action(printerService)
            await loadPrinter()
        } catch {
            actionError = error.localizedDescription
        }

        isPerformingAction = false
    }
}
