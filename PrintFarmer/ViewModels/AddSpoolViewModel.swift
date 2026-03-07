import Foundation
import os

@MainActor @Observable
final class AddSpoolViewModel {
    // Form fields
    var filamentName = ""
    var selectedMaterial = ""
    var selectedVendor = ""
    var colorHex = "#10b981"
    var totalWeightG: Double = 1000
    var spoolWeightG: Double = 200

    // Reference data
    var materials: [SpoolmanMaterial] = []
    var vendors: [SpoolmanVendor] = []
    var filaments: [SpoolmanFilament] = []

    // State
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "AddSpool")
    private var spoolService: (any SpoolServiceProtocol)?

    func configure(spoolService: any SpoolServiceProtocol) {
        self.spoolService = spoolService
    }

    var isFormValid: Bool {
        !selectedMaterial.isEmpty && totalWeightG > 0
    }

    /// Pre-defined color swatches for quick selection
    static let colorSwatches: [(name: String, hex: String)] = [
        ("Black", "#000000"),
        ("White", "#FFFFFF"),
        ("Red", "#E53E3E"),
        ("Blue", "#3182CE"),
        ("Green", "#38A169"),
        ("Yellow", "#D69E2E"),
        ("Orange", "#DD6B20"),
        ("Purple", "#805AD5"),
        ("Pink", "#D53F8C"),
        ("Gray", "#718096"),
        ("Silver", "#CBD5E0"),
        ("Gold", "#D4A837"),
    ]

    func loadReferenceData() async {
        guard let spoolService else {
            errorMessage = "Spool service not available"
            return
        }

        isLoading = true

        do {
            async let mats = spoolService.listMaterials()
            async let vends = spoolService.listVendors()
            async let fils = spoolService.listFilaments()
            materials = try await mats
            vendors = try await vends
            filaments = try await fils
        } catch {
            logger.warning("Failed to load reference data: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func saveSpool() async {
        guard let spoolService, isFormValid else { return }

        isSaving = true
        errorMessage = nil

        // Find filament ID matching the selected material + vendor combo
        let matchingFilament = filaments.first { fil in
            fil.material?.lowercased() == selectedMaterial.lowercased()
            && (selectedVendor.isEmpty || fil.vendor?.lowercased() == selectedVendor.lowercased())
        }

        let request = SpoolmanSpoolRequest(
            filamentId: matchingFilament?.id,
            remainingWeight: totalWeightG,
            initialWeight: totalWeightG,
            spoolWeight: spoolWeightG > 0 ? spoolWeightG : nil
        )

        do {
            _ = try await spoolService.createSpool(request)
            didSave = true
        } catch {
            logger.warning("Failed to create spool: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
