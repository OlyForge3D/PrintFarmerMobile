import Foundation

// MARK: - Printer Service

actor PrinterService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func list(includeDisabled: Bool = false) async throws -> [Printer] {
        let query = includeDisabled ? "?includeDisabled=true" : ""
        return try await apiClient.get("/api/printers\(query)")
    }

    func get(id: UUID) async throws -> Printer {
        try await apiClient.get("/api/printers/\(id)")
    }

    func update(id: UUID, _ request: UpdatePrinterRequest) async throws -> Printer {
        try await apiClient.put("/api/printers/\(id)", body: request)
    }

    func delete(id: UUID) async throws {
        try await apiClient.delete("/api/printers/\(id)")
    }

    func setMaintenanceMode(id: UUID, inMaintenance: Bool) async throws -> Printer {
        try await apiClient.put("/api/printers/\(id)/maintenance", body: inMaintenance)
    }

    func sendCommand(printerId: UUID, command: String) async throws {
        try await apiClient.post("/api/printers/\(printerId)/command/\(command)")
    }
}
