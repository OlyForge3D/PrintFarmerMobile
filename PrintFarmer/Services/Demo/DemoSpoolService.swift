import Foundation

// MARK: - Demo Spool Service

final class DemoSpoolService: SpoolServiceProtocol, @unchecked Sendable {
    private let allSpools = DemoData.spools

    func listSpools(limit: Int, offset: Int, search: String?, material: String?, vendor: String?) async throws -> SpoolmanPagedResult<SpoolmanSpool> {
        var filtered = allSpools
        if let search, !search.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        if let material, !material.isEmpty {
            filtered = filtered.filter { $0.material == material }
        }
        if let vendor, !vendor.isEmpty {
            filtered = filtered.filter { $0.vendor == vendor }
        }
        let total = filtered.count
        let page = Array(filtered.dropFirst(offset).prefix(limit))
        return SpoolmanPagedResult(items: page, totalCount: total)
    }

    func createSpool(_ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool {
        throw ServiceError.notImplemented("createSpool — read-only in demo mode")
    }

    func updateSpool(id: Int, _ request: SpoolmanSpoolRequest) async throws -> SpoolmanSpool {
        throw ServiceError.notImplemented("updateSpool — read-only in demo mode")
    }

    func deleteSpool(id: Int) async throws {}

    func listFilaments() async throws -> [SpoolmanFilament] {
        [
            SpoolmanFilament(id: 1, name: "Prusament PLA", material: "PLA", colorHex: "#000000",
                             vendor: "Prusa Research", density: 1.24, diameter: 1.75, weight: 1000,
                             spoolWeight: 200, price: 24.99, settingsExtruderTemp: 215,
                             settingsBedTemp: 60, articleNumber: "PRM-PLA-BK", comment: nil,
                             multiColorHexes: nil, externalId: nil),
            SpoolmanFilament(id: 2, name: "eSun PETG", material: "PETG", colorHex: "#FFFFFF",
                             vendor: "eSun", density: 1.27, diameter: 1.75, weight: 1000,
                             spoolWeight: 180, price: 19.99, settingsExtruderTemp: 240,
                             settingsBedTemp: 80, articleNumber: nil, comment: nil,
                             multiColorHexes: nil, externalId: nil),
            SpoolmanFilament(id: 3, name: "Hatchbox ABS", material: "ABS", colorHex: "#FFFFFF",
                             vendor: "Hatchbox", density: 1.04, diameter: 1.75, weight: 1000,
                             spoolWeight: 220, price: 22.99, settingsExtruderTemp: 240,
                             settingsBedTemp: 100, articleNumber: nil, comment: nil,
                             multiColorHexes: nil, externalId: nil),
        ]
    }

    func listVendors() async throws -> [SpoolmanVendor] {
        [
            SpoolmanVendor(id: 1, name: "Prusa Research", externalId: nil),
            SpoolmanVendor(id: 2, name: "eSun", externalId: nil),
            SpoolmanVendor(id: 3, name: "Hatchbox", externalId: nil),
            SpoolmanVendor(id: 4, name: "NinjaTek", externalId: nil),
            SpoolmanVendor(id: 5, name: "Polymaker", externalId: nil),
        ]
    }

    func listMaterials() async throws -> [SpoolmanMaterial] {
        [
            SpoolmanMaterial(id: 1, name: "PLA", density: 1.24, colorHex: nil),
            SpoolmanMaterial(id: 2, name: "PETG", density: 1.27, colorHex: nil),
            SpoolmanMaterial(id: 3, name: "ABS", density: 1.04, colorHex: nil),
            SpoolmanMaterial(id: 4, name: "TPU", density: 1.21, colorHex: nil),
            SpoolmanMaterial(id: 5, name: "ASA", density: 1.07, colorHex: nil),
        ]
    }

    func listAvailableMaterials() async throws -> [String] {
        ["PLA", "PETG", "ABS", "TPU", "ASA"]
    }
}
