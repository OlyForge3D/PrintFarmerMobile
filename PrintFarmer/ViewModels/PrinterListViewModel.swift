import Foundation

@Observable
final class PrinterListViewModel: @unchecked Sendable {
    var printers: [Printer] = []
    var isLoading = false
    var errorMessage: String?

    private let printerService: PrinterService

    init(printerService: PrinterService) {
        self.printerService = printerService
    }

    func loadPrinters() async {
        isLoading = true
        errorMessage = nil

        do {
            printers = try await printerService.list()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
