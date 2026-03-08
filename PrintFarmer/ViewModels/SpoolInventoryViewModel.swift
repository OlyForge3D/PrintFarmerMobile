import Foundation
import os

enum SpoolStatus: String, CaseIterable {
    case available = "Available"
    case inUse = "In Use"
    case low = "Low"
    case empty = "Empty"
}

@MainActor @Observable
final class SpoolInventoryViewModel {
    var spools: [SpoolmanSpool] = []
    var searchText = ""
    var selectedMaterial: String?
    var selectedStatus: SpoolStatus?
    var isLoading = false
    var errorMessage: String?

    // NFC scanning state
    var isScanning = false
    var scanError: String?
    var scannedSpoolData: ScannedSpoolData?
    var showScannedDataSheet = false
    var highlightedSpoolId: Int?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "SpoolInventory")
    private var spoolService: (any SpoolServiceProtocol)?
    private var nfcScanner: (any SpoolScannerProtocol)?

    func configure(spoolService: any SpoolServiceProtocol) {
        self.spoolService = spoolService
    }

    func configureNFC(scanner: any SpoolScannerProtocol) {
        self.nfcScanner = scanner
    }

    var availableMaterials: [String] {
        let materials = Set(spools.map { $0.material })
        return materials.sorted()
    }

    var filteredSpools: [SpoolmanSpool] {
        var result = spools

        // Apply material filter first
        if let material = selectedMaterial {
            result = result.filter { $0.material == material }
        }

        // Apply status filter
        if let status = selectedStatus {
            result = result.filter { spool in
                switch status {
                case .available:
                    return !spool.inUse && !(spool.archived ?? false)
                case .inUse:
                    return spool.inUse
                case .low:
                    guard let remaining = spool.remainingWeightG,
                          let initial = spool.initialWeightG,
                          initial > 0 else { return false }
                    return (remaining / initial) < 0.2
                case .empty:
                    if let remaining = spool.remainingWeightG {
                        return remaining == 0
                    } else if spool.initialWeightG != nil {
                        return true
                    }
                    return false
                }
            }
        }

        // Then apply search text filter
        guard !searchText.isEmpty else { return result }
        let query = searchText.lowercased()
        return result.filter { spool in
            spool.material.lowercased().contains(query)
            || (spool.filamentName?.lowercased().contains(query) ?? false)
            || (spool.vendor?.lowercased().contains(query) ?? false)
            || spool.name.lowercased().contains(query)
            || (spool.location?.lowercased().contains(query) ?? false)
            || (spool.comment?.lowercased().contains(query) ?? false)
            || spool.colorNameMatches(query)
        }
    }

    var hasActiveSearch: Bool {
        !searchText.isEmpty || selectedMaterial != nil || selectedStatus != nil
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
            spools = result.items
        } catch {
            logger.warning("Failed to load spools: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

    func findSpool(byId id: Int) -> SpoolmanSpool? {
        spools.first { $0.id == id }
    }

    func clearHighlight() {
        highlightedSpoolId = nil
    }

    private func handleScanResult(_ result: SpoolScanResult) async {
        switch result {
        case .spoolId(let id):
            if let existing = findSpool(byId: id) {
                highlightedSpoolId = existing.id
            } else {
                // Reload and try again
                await loadSpools()
                if let existing = findSpool(byId: id) {
                    highlightedSpoolId = existing.id
                } else {
                    scanError = "Spool #\(id) not found in inventory."
                }
            }

        case .newSpoolData(let data):
            scannedSpoolData = data
            showScannedDataSheet = true

        case .cancelled:
            break

        case .error(let error):
            scanError = error.localizedDescription
        }
    }

    func deleteSpool(_ spool: SpoolmanSpool) async {
        guard let spoolService else { return }

        do {
            try await spoolService.deleteSpool(id: spool.id)
            spools.removeAll { $0.id == spool.id }
        } catch {
            logger.warning("Failed to delete spool: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
