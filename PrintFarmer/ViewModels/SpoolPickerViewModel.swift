import Foundation
import os

@MainActor @Observable
final class SpoolPickerViewModel {
    var spools: [SpoolmanSpool] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "SpoolPicker")
    private var spoolService: (any SpoolServiceProtocol)?

    func configure(spoolService: any SpoolServiceProtocol) {
        self.spoolService = spoolService
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
}
