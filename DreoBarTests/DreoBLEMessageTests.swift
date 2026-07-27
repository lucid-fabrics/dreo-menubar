import XCTest
@testable import DreoBar

final class DreoBLEMessageTests: XCTestCase {
    static let sampleNetworkCBOR = CBORValue.map([
        ("s", .text("TestWiFi")), ("r", .negative(-49)), ("a", .unsigned(3)), ("c", .unsigned(1))
    ])

    func test_setTime_encodesTimestampSeconds() throws {
        let date = Date(timeIntervalSince1970: 1_785_000_000)
        let decoded = try CBOR.decode(DreoBLEMessage.setTime(date))

        XCTAssertEqual(decoded["t"]?.stringValue, "st")
        XCTAssertEqual(decoded["v"], .bytes(Data([0x00, 0x00, 0x01])))
        XCTAssertEqual(decoded["d"]?["t"]?.intValue, 1_785_000_000)
    }

    func test_requestWiFiScan_encodesChannelsOneThroughThirteen() throws {
        let decoded = try CBOR.decode(DreoBLEMessage.requestWiFiScan())

        XCTAssertEqual(decoded["t"]?.stringValue, "rw")
        XCTAssertEqual(decoded["d"]?["o"]?.arrayValue?.map(\.intValue), Array(1...13))
        XCTAssertEqual(decoded["d"]?["t"]?.intValue, 300)
    }

    func test_provisionDomains_encodesUserIdAndHost() throws {
        let data = DreoBLEMessage.provisionDomains(
            userId: 1234567890123456789,
            deviceAPIHost: "https://device-api-us.dreo-cloud.com"
        )
        let decoded = try CBOR.decode(data)

        XCTAssertEqual(decoded["t"]?.stringValue, "pd")
        XCTAssertEqual(decoded["d"]?["u"]?.intValue, 1234567890123456789)
        XCTAssertEqual(decoded["d"]?["h"]?["1"]?.stringValue, "https://device-api-us.dreo-cloud.com")
        XCTAssertEqual(decoded["d"]?["a"]?["o"]?["p"]?.stringValue, "/api/oauth/login")
    }

    func test_connectWiFi_sendsPlaintextPasswordAndOmitsVersion() throws {
        let discovered = try XCTUnwrap(DiscoveredWiFiNetwork(cbor: Self.sampleNetworkCBOR))

        let data = DreoBLEMessage.connectWiFi(network: discovered, password: "hunter2")
        let decoded = try CBOR.decode(data)

        XCTAssertNil(decoded["v"])
        XCTAssertEqual(decoded["t"]?.stringValue, "cw")
        XCTAssertEqual(decoded["d"]?["s"]?.stringValue, "TestWiFi")
        XCTAssertEqual(decoded["d"]?["p"]?.stringValue, "hunter2")
        XCTAssertEqual(decoded["d"]?["c"]?.intValue, 1)
        XCTAssertEqual(decoded["d"]?["a"]?.intValue, 3)
    }

    func test_connectWiFi_matchesRealCaptureFieldOrder() throws {
        let discovered = try XCTUnwrap(DiscoveredWiFiNetwork(cbor: Self.sampleNetworkCBOR))

        let data = DreoBLEMessage.connectWiFi(network: discovered, password: "test-password")

        // Captured live against a real fan (2026-07-27); the fan's firmware
        // parses this map positionally, so field order must match exactly.
        let expectedOrder = ["a", "b", "c", "m", "p", "s", "t", "sc", "scc"]
        guard case .map(let entries) = try CBOR.decode(data)["d"]! else {
            return XCTFail("expected a map")
        }
        XCTAssertEqual(entries.map(\.0), expectedOrder)
    }

    func test_notification_decodesWifiList() throws {
        let payload = CBOR.encode(.map([
            ("t", .text("wl")),
            ("v", .bytes(Data([0x01, 0x00, 0x03]))),
            ("d", .map([("l", .array([Self.sampleNetworkCBOR]))]))
        ]))

        guard case .wifiNetworks(let networks) = try XCTUnwrap(DreoBLENotification(data: payload)) else {
            return XCTFail("expected .wifiNetworks")
        }
        XCTAssertEqual(networks.first?.ssid, "TestWiFi")
    }

    func test_notification_decodesConnectFinishedSuccess() throws {
        let payload = CBOR.encode(.map([
            ("t", .text("cf")),
            ("v", .bytes(Data([0x01, 0x00, 0x03]))),
            ("d", .map([("r", .bool(true))]))
        ]))

        XCTAssertEqual(DreoBLENotification(data: payload), .connectFinished(success: true))
    }

    func test_notification_decodesErrorCodeFromEnvelopeLevelField() throws {
        // Captured live against a real fan (2026-07-27): unlike every other
        // notification, "ee" carries its payload directly on "e", not
        // nested under "d".
        let payload = CBOR.encode(.map([
            ("t", .text("ee")),
            ("v", .bytes(Data([0x01, 0x00, 0x03]))),
            ("e", .bytes(Data([0x03, 0x02, 0x00, 0x01])))
        ]))

        XCTAssertEqual(DreoBLENotification(data: payload), .error(code: Data([0x03, 0x02, 0x00, 0x01])))
    }
}
