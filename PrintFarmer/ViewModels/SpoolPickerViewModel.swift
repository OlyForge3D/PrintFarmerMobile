import Foundation
import os

@MainActor @Observable
final class SpoolPickerViewModel {
    var spools: [SpoolmanSpool] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    // Scanning state
    var isQRScannerPresented = false
    var isScanning = false
    var scanError: String?
    var scannedSpoolData: ScannedSpoolData?
    var showScannedDataSheet = false

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "SpoolPicker")
    private var spoolService: (any SpoolServiceProtocol)?
    private var nfcScanner: (any SpoolScannerProtocol)?

    /// Callback set by the view when a spool is auto-selected via scan
    var onAutoSelect: ((SpoolmanSpool) -> Void)?

    func configure(spoolService: any SpoolServiceProtocol) {
        self.spoolService = spoolService
    }

    func configureNFCScanner(_ scanner: any SpoolScannerProtocol) {
        self.nfcScanner = scanner
    }

    var filteredSpools: [SpoolmanSpool] {
        guard !searchText.isEmpty else { return spools }
        let query = searchText.lowercased()
        return spools.filter { spool in
            spool.material.lowercased().contains(query)
            || (spool.filamentName?.lowercased().contains(query) ?? false)
            || (spool.vendor?.lowercased().contains(query) ?? false)
            || spool.name.lowercased().contains(query)
        }
    }

    func loadSpools() async {
        guard let spoolService else {
            errorMessage = "Spool service not available"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await spoolService.listSpools(limit: 200, offset: 0)
            spools = result.items.filter { !($0.archived ?? false) }
        } catch {
            logger.warning("Failed to load spools: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - QR Scanning

    func handleQRScan(qrText: String) {
        isQRScannerPresented = false

        // Try to parse a spool ID from the QR text
        // Common formats: plain integer, URL with /spool/{id}, JSON with "id" field
        if let spoolId = parseSpoolId(from: qrText) {
            Task { await fetchAndSelectSpool(id: spoolId) }
        } else {
            scanError = "Could not find a spool ID in the scanned QR code."
        }
    }

    // MARK: - NFC Scanning

    func handleNFCScan() {
        guard let nfcScanner, nfcScanner.isAvailable else {
            scanError = "NFC scanning is not available on this device."
            return
        }

        isScanning = true
        scanError = nil

        Task {
            let result = await nfcScanner.scan()
            await handleScanResult(result)
            isScanning = false
        }
    }

    // MARK: - Shared Scan Result Handler

    func handleScanResult(_ result: SpoolScanResult) async {
        switch result {
        case .spoolId(let id):
            await fetchAndSelectSpool(id: id)

        case .newSpoolData(let data):
            scannedSpoolData = data
            showScannedDataSheet = true

        case .cancelled:
            break

        case .error(let error):
            scanError = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func fetchAndSelectSpool(id: Int) async {
        guard let spoolService else {
            scanError = "Spool service not available"
            return
        }

        isScanning = true
        scanError = nil

        do {
            // Search loaded spools first
            if let existing = spools.first(where: { $0.id == id }) {
                onAutoSelect?(existing)
                isScanning = false
                return
            }

            // Reload and search again
            let result = try await spoolService.listSpools(limit: 200, offset: 0)
            spools = result.items.filter { !($0.archived ?? false) }

            if let spool = spools.first(where: { $0.id == id }) {
                onAutoSelect?(spool)
            } else {
                scanError = "Spool #\(id) not found in inventory."
            }
        } catch {
            logger.warning("Failed to fetch spool #\(id): \(error.localizedDescription)")
            scanError = error.localizedDescription
        }

        isScanning = false
    }

    private func parseSpoolId(from text: String) -> Int? {
        // Plain integer
        if let id = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return id
        }

        // URL path: .../spool/123 or .../spools/123
        if let url = URL(string: text) {
            let components = url.pathComponents
            for (index, component) in components.enumerated() {
                if component == "spool" || component == "spools",
                   index + 1 < components.count,
                   let id = Int(components[index + 1]) {
                    return id
                }
            }
        }

        // JSON: {"id": 123} or {"spoolId": 123}
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let id = json["id"] as? Int { return id }
            if let id = json["spoolId"] as? Int { return id }
            if let id = json["spool_id"] as? Int { return id }
        }

        return nil
    }
}
