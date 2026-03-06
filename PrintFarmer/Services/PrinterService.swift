import Foundation

// MARK: - Printer Service

actor PrinterService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func list() async throws -> [Printer] {
        try await apiClient.get("/api/printers")
    }

    func get(id: UUID) async throws -> Printer {
        try await apiClient.get("/api/printers/\(id)")
    }

    func getStatus(id: UUID) async throws -> Printer {
        try await apiClient.get("/api/printers/\(id)/status")
    }

    func delete(id: UUID) async throws {
        try await apiClient.delete("/api/printers/\(id)")
    }

    func sendCommand(printerId: UUID, command: String) async throws {
        try await apiClient.post("/api/printers/\(printerId)/command/\(command)")
    }
}
