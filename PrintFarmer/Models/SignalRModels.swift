import Foundation

// MARK: - SignalR Event DTOs

struct PrinterStatusUpdate: Codable, Sendable {
    let id: UUID
    let isOnline: Bool
    let state: String?
    let progress: Double?
    let jobName: String?
    let thumbnailUrl: String?
    let cameraStreamUrl: String?
    let x: Double?
    let y: Double?
    let z: Double?
    let hotendTemp: Double?
    let bedTemp: Double?
    let hotendTarget: Double?
    let bedTarget: Double?
    let homedAxes: String?
    let spoolInfo: PrinterSpoolInfo?
}

struct PrinterStateUpdate: Codable, Sendable {
    let printerId: UUID
    let state: String?
    let progress: Double?
    let jobName: String?
}

struct PrinterExtruderUpdate: Codable, Sendable {
    let printerId: UUID
    let temperature: Double?
    let target: Double?
}

struct PrinterHeaterBedUpdate: Codable, Sendable {
    let printerId: UUID
    let temperature: Double?
    let target: Double?
}

struct PrinterToolheadUpdate: Codable, Sendable {
    let printerId: UUID
    let x: Double?
    let y: Double?
    let z: Double?
}

struct DiscoveryProgressUpdate: Codable, Sendable {
    let currentIp: String?
    let progress: Double
    let printersFound: Int
}

struct DiscoveryPrinterFoundUpdate: Codable, Sendable {
    let ip: String
    let name: String?
    let backend: PrinterBackend
}
