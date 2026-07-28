import XCTest
@testable import Windbar

final class CBORTests: XCTestCase {
    func test_roundTrip_mapOfMixedTypes() throws {
        let value = CBORValue.map([
            ("t", .text("st")),
            ("v", .bytes(Data([0x00, 0x00, 0x01]))),
            ("d", .map([
                ("flag", .bool(true)),
                ("empty", .null),
                ("list", .array([.unsigned(1), .unsigned(2), .negative(-3)]))
            ]))
        ])

        let decoded = try CBOR.decode(CBOR.encode(value))

        XCTAssertEqual(decoded["t"]?.stringValue, "st")
        XCTAssertEqual(decoded["v"], .bytes(Data([0x00, 0x00, 0x01])))
        XCTAssertEqual(decoded["d"]?["flag"]?.boolValue, true)
        XCTAssertEqual(decoded["d"]?["empty"], .null)
        XCTAssertEqual(decoded["d"]?["list"]?.arrayValue?.map(\.intValue), [1, 2, -3])
    }

    func test_decode_realWifiListNotification() throws {
        // Captured live via Frida against a real fan (2026-07-27), 36 bytes:
        // {"t":"wl","v":h'010003',"d":{"l":[{"s":"Lynk","r":-53,"a":3,"c":2}]}}
        let hex = "a3617462776c6176430100036164a1616c81a46173644c796e6b61723834616103616302"
        let bytes = stride(from: 0, to: hex.count, by: 2).map { offset -> UInt8 in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)!
        }
        XCTAssertEqual(bytes.count, 36)

        let decoded = try CBOR.decode(Data(bytes))
        XCTAssertEqual(decoded["t"]?.stringValue, "wl")
        let network = decoded["d"]?["l"]?.arrayValue?.first
        XCTAssertEqual(network?["s"]?.stringValue, "Lynk")
        XCTAssertEqual(network?["r"]?.intValue, -53)
        XCTAssertEqual(network?["a"]?.intValue, 3)
        XCTAssertEqual(network?["c"]?.intValue, 2)
    }

    func test_decode_truncatedData_throws() {
        XCTAssertThrowsError(try CBOR.decode(Data([0xA1]))) // map(1) with no entries following
    }

    func test_encode_largeUnsignedUsesCorrectHeaderWidth() throws {
        let value = CBORValue.unsigned(1_000_000)
        let decoded = try CBOR.decode(CBOR.encode(value))
        XCTAssertEqual(decoded.intValue, 1_000_000)
    }
}
