import Foundation

@MainActor @Observable
final class PrinterListViewModel {
    var printers: [Printer] = []
    var locations: [Location] = []
    var isLoading = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedStatus: StatusFilter = .all
    var selectedLocationId: UUID?

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case online = "Online"
        case printing = "Printing"
        case offline = "Offline"
        case error = "Error"

        var id: String { rawValue }
    }

    private var printerService: (any PrinterServiceProtocol)?

    func configure(printerService: any PrinterServiceProtocol) {
        self.printerService = printerService
    }

    func loadPrinters() async {
        guard let printerService else { return }
        isLoading = true
        errorMessage = nil

        do {
            printers = try await printerService.list()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtered Results

    var filteredPrinters: [Printer] {
        printers.filter { printer in
            matchesSearch(printer) && matchesStatus(printer) && matchesLocation(printer)
        }
    }

    private func matchesSearch(_ printer: Printer) -> Bool {
        guard !searchText.isEmpty else { return true }
        return printer.name.localizedCaseInsensitiveContains(searchText)
    }

    private func matchesStatus(_ printer: Printer) -> Bool {
        switch selectedStatus {
        case .all: return true
        case .online: return printer.isOnline
        case .printing: return printer.state?.lowercased() == "printing"
        case .offline: return !printer.isOnline
        case .error: return printer.state?.lowercased() == "error"
        }
    }

    private func matchesLocation(_ printer: Printer) -> Bool {
        guard let locationId = selectedLocationId else { return true }
        return printer.location?.id == locationId
    }

    /// Unique locations from loaded printers.
    var availableLocations: [LocationSummary] {
        let seen = NSMutableSet()
        return printers.compactMap(\.location).filter { loc in
            guard !seen.contains(loc.id) else { return false }
            seen.add(loc.id)
            return true
        }
    }
}
