import Foundation

// MARK: - API Request DTOs

struct CreatePrintJobRequest: Codable, Sendable {
    let name: String
    let priority: Int
    let gcodeFileId: UUID
    let hotendTemperature: Double?
    let bedTemperature: Double?
    let spoolId: Int?
    let requiredCapabilities: [String]?
    let autoAssign: Bool
    let preferredPrinterIds: [UUID]?
    let excludedPrinterIds: [UUID]?
}

struct UpdatePrintJobRequest: Codable, Sendable {
    let name: String
    let priority: Int
    let hotendTemperature: Double?
    let bedTemperature: Double?
    let spoolId: Int?
    let requiredCapabilities: [String]?
    let autoAssign: Bool
    let preferredPrinterIds: [UUID]?
    let excludedPrinterIds: [UUID]?
}

struct CreateLocationRequest: Codable, Sendable {
    let name: String
    let description: String?
}

struct UpdateLocationRequest: Codable, Sendable {
    let name: String?
    let description: String?
}

// MARK: - API Response Wrappers

struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
}

struct APIError: Codable, Sendable {
    let title: String?
    let status: Int?
    let detail: String?
    let errors: [String: [String]]?
}
