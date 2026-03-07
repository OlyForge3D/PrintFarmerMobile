import Foundation

// MARK: - NFC Tag Parser

/// Parses and creates NFC tag payloads for spool identification.
enum NFCTagParser {

    // MARK: - OpenSpool Format

    /// Parses an OpenSpool JSON payload into ScannedSpoolData.
    /// OpenSpool fields: material, color_hex, brand, weight_g, diameter_mm, temp_c, spoolman_id
    static func parseOpenSpool(_ data: Data) -> ScannedSpoolData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return ScannedSpoolData(
            material: json["material"] as? String,
            colorHex: json["color_hex"] as? String,
            vendor: json["brand"] as? String,
            weight: doubleValue(json["weight_g"]),
            diameter: doubleValue(json["diameter_mm"]),
            temperature: intValue(json["temp_c"]),
            spoolmanId: intValue(json["spoolman_id"])
        )
    }

    // MARK: - OpenPrintTag Format

    /// Parses an OpenPrintTag JSON payload into ScannedSpoolData.
    /// OpenPrintTag fields: filament_type, color, manufacturer, net_weight, filament_diameter, print_temp, spool_id
    static func parseOpenPrintTag(_ data: Data) -> ScannedSpoolData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return ScannedSpoolData(
            material: json["filament_type"] as? String,
            colorHex: json["color"] as? String,
            vendor: json["manufacturer"] as? String,
            weight: doubleValue(json["net_weight"]),
            diameter: doubleValue(json["filament_diameter"]),
            temperature: intValue(json["print_temp"]),
            spoolmanId: intValue(json["spool_id"])
        )
    }

    // MARK: - Payload Creation

    /// Creates an OpenSpool JSON payload from a SpoolmanSpool.
    static func createOpenSpoolPayload(from spool: SpoolmanSpool) -> Data? {
        var payload: [String: Any] = [:]
        payload["material"] = spool.material
        if let hex = spool.colorHex { payload["color_hex"] = hex }
        if let vendor = spool.vendor { payload["brand"] = vendor }
        if let weight = spool.initialWeightG { payload["weight_g"] = weight }
        payload["spoolman_id"] = spool.id

        return try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    // MARK: - Helpers

    private static func doubleValue(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String { return Int(s) }
        return nil
    }
}
