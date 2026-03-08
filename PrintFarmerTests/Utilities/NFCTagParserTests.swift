import XCTest
@testable import PrintFarmer

/// Tests for NFCTagParser: OpenSpool/OpenPrintTag parsing, payload creation, and edge cases.
final class NFCTagParserTests: XCTestCase {

    // MARK: - OpenSpool: All Fields

    func testOpenSpoolAllFields() throws {
        let json: [String: Any] = [
            "material": "PLA",
            "color_hex": "#FF5733",
            "brand": "Prusament",
            "weight_g": 1000.0,
            "diameter_mm": 1.75,
            "temp_c": 215,
            "spoolman_id": 42
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenSpool(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.material, "PLA")
        XCTAssertEqual(result?.colorHex, "#FF5733")
        XCTAssertEqual(result?.vendor, "Prusament")
        XCTAssertEqual(result?.weight, 1000.0)
        XCTAssertEqual(result?.diameter, 1.75)
        XCTAssertEqual(result?.temperature, 215)
        XCTAssertEqual(result?.spoolmanId, 42)
    }

    // MARK: - OpenSpool: Partial Fields

    func testOpenSpoolMaterialOnly() throws {
        let json: [String: Any] = ["material": "PETG"]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenSpool(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.material, "PETG")
        XCTAssertNil(result?.colorHex)
        XCTAssertNil(result?.vendor)
        XCTAssertNil(result?.weight)
        XCTAssertNil(result?.diameter)
        XCTAssertNil(result?.temperature)
        XCTAssertNil(result?.spoolmanId)
    }

    func testOpenSpoolColorOnly() throws {
        let json: [String: Any] = ["color_hex": "#000000"]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenSpool(data)

        XCTAssertNotNil(result)
        XCTAssertNil(result?.material)
        XCTAssertEqual(result?.colorHex, "#000000")
    }

    func testOpenSpoolSpoolmanIdOnly() throws {
        let json: [String: Any] = ["spoolman_id": 99]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenSpool(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spoolmanId, 99)
        XCTAssertNil(result?.material)
    }

    // MARK: - OpenSpool: Edge Cases

    func testOpenSpoolEmptyJSON() throws {
        let data = try JSONSerialization.data(withJSONObject: [String: Any]())

        let result = NFCTagParser.parseOpenSpool(data)

        // Empty JSON returns a ScannedSpoolData with all nils
        XCTAssertNotNil(result)
        XCTAssertNil(result?.material)
        XCTAssertNil(result?.spoolmanId)
    }

    func testOpenSpoolInvalidData() {
        let data = Data("not json".utf8)
        XCTAssertNil(NFCTagParser.parseOpenSpool(data))
    }

    func testOpenSpoolEmptyData() {
        let data = Data()
        XCTAssertNil(NFCTagParser.parseOpenSpool(data))
    }

    func testOpenSpoolIntegerWeightAsInt() throws {
        let json: [String: Any] = ["weight_g": 800]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenSpool(data)

        XCTAssertEqual(result?.weight, 800.0)
    }

    func testOpenSpoolStringTypedValues() throws {
        let json: [String: Any] = [
            "weight_g": "750.5",
            "temp_c": "210",
            "spoolman_id": "42"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenSpool(data)

        XCTAssertEqual(result?.weight, 750.5)
        XCTAssertEqual(result?.temperature, 210)
        XCTAssertEqual(result?.spoolmanId, 42)
    }

    // MARK: - OpenPrintTag: All Fields

    func testOpenPrintTagAllFields() throws {
        let json: [String: Any] = [
            "filament_type": "ABS",
            "color": "#222222",
            "manufacturer": "Hatchbox",
            "net_weight": 750.0,
            "filament_diameter": 1.75,
            "print_temp": 240,
            "spool_id": 88
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenPrintTag(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.material, "ABS")
        XCTAssertEqual(result?.colorHex, "#222222")
        XCTAssertEqual(result?.vendor, "Hatchbox")
        XCTAssertEqual(result?.weight, 750.0)
        XCTAssertEqual(result?.diameter, 1.75)
        XCTAssertEqual(result?.temperature, 240)
        XCTAssertEqual(result?.spoolmanId, 88)
    }

    // MARK: - OpenPrintTag: Partial Fields

    func testOpenPrintTagMaterialOnly() throws {
        let json: [String: Any] = ["filament_type": "TPU"]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenPrintTag(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.material, "TPU")
        XCTAssertNil(result?.vendor)
        XCTAssertNil(result?.spoolmanId)
    }

    func testOpenPrintTagManufacturerAndColor() throws {
        let json: [String: Any] = [
            "manufacturer": "eSUN",
            "color": "#FFFFFF"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let result = NFCTagParser.parseOpenPrintTag(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.vendor, "eSUN")
        XCTAssertEqual(result?.colorHex, "#FFFFFF")
        XCTAssertNil(result?.material)
    }

    // MARK: - OpenPrintTag: Edge Cases

    func testOpenPrintTagInvalidData() {
        let data = Data([0xFF, 0xFE, 0x00])
        XCTAssertNil(NFCTagParser.parseOpenPrintTag(data))
    }

    func testOpenPrintTagArrayJSON() throws {
        let data = try JSONSerialization.data(withJSONObject: [1, 2, 3])
        XCTAssertNil(NFCTagParser.parseOpenPrintTag(data))
    }

    // MARK: - Payload Creation

    func testCreateOpenSpoolPayloadRoundTrip() throws {
        let spool = SpoolmanSpool(
            id: 42,
            name: "Black PLA",
            material: "PLA",
            colorHex: "#000000",
            inUse: true,
            filamentName: "Prusament PLA",
            vendor: "Prusa Research",
            registeredAt: nil,
            firstUsedAt: nil,
            lastUsedAt: nil,
            remainingWeightG: 750.0,
            initialWeightG: 1000.0,
            usedWeightG: 250.0,
            spoolWeightG: 200.0,
            remainingLengthMm: nil,
            usedLengthMm: nil,
            location: nil,
            lotNumber: nil,
            archived: false,
            price: nil,
            comment: nil,
            usedPercent: nil,
            remainingPercent: nil
        )

        let payload = NFCTagParser.createOpenSpoolPayload(from: spool)
        XCTAssertNotNil(payload)

        let parsed = NFCTagParser.parseOpenSpool(payload!)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.material, "PLA")
        XCTAssertEqual(parsed?.colorHex, "#000000")
        XCTAssertEqual(parsed?.vendor, "Prusa Research")
        XCTAssertEqual(parsed?.weight, 1000.0)
        XCTAssertEqual(parsed?.spoolmanId, 42)
    }

    func testCreateOpenSpoolPayloadMinimalFields() throws {
        let spool = SpoolmanSpool(
            id: 7,
            name: "Generic",
            material: "PETG",
            colorHex: nil,
            inUse: false,
            filamentName: nil,
            vendor: nil,
            registeredAt: nil,
            firstUsedAt: nil,
            lastUsedAt: nil,
            remainingWeightG: nil,
            initialWeightG: nil,
            usedWeightG: nil,
            spoolWeightG: nil,
            remainingLengthMm: nil,
            usedLengthMm: nil,
            location: nil,
            lotNumber: nil,
            archived: nil,
            price: nil,
            comment: nil,
            usedPercent: nil,
            remainingPercent: nil
        )

        let payload = NFCTagParser.createOpenSpoolPayload(from: spool)
        XCTAssertNotNil(payload)

        let parsed = NFCTagParser.parseOpenSpool(payload!)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.material, "PETG")
        XCTAssertEqual(parsed?.spoolmanId, 7)
        XCTAssertNil(parsed?.colorHex)
        XCTAssertNil(parsed?.vendor)
        XCTAssertNil(parsed?.weight)
    }

    func testCreateOpenSpoolPayloadIsValidJSON() throws {
        let spool = SpoolmanSpool(
            id: 1,
            name: "Test",
            material: "PLA",
            colorHex: "#FF0000",
            inUse: false,
            filamentName: nil,
            vendor: "TestVendor",
            registeredAt: nil,
            firstUsedAt: nil,
            lastUsedAt: nil,
            remainingWeightG: nil,
            initialWeightG: 500.0,
            usedWeightG: nil,
            spoolWeightG: nil,
            remainingLengthMm: nil,
            usedLengthMm: nil,
            location: nil,
            lotNumber: nil,
            archived: nil,
            price: nil,
            comment: nil,
            usedPercent: nil,
            remainingPercent: nil
        )

        let payload = NFCTagParser.createOpenSpoolPayload(from: spool)!
        let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["material"] as? String, "PLA")
        XCTAssertEqual(json?["color_hex"] as? String, "#FF0000")
        XCTAssertEqual(json?["brand"] as? String, "TestVendor")
        XCTAssertEqual(json?["spoolman_id"] as? Int, 1)
    }
}
