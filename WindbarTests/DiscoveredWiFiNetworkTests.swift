import XCTest
@testable import Windbar

final class DiscoveredWiFiNetworkTests: XCTestCase {
    func test_init_parsesCBORMap() throws {
        let cbor = CBORValue.map([
            ("s", .text("HomeWiFi")),
            ("r", .negative(-55)),
            ("a", .unsigned(3)),
            ("c", .unsigned(11))
        ])

        let network = try XCTUnwrap(DiscoveredWiFiNetwork(cbor: cbor))

        XCTAssertEqual(network.ssid, "HomeWiFi")
        XCTAssertEqual(network.rssi, -55)
        XCTAssertEqual(network.authType, 3)
        XCTAssertEqual(network.channel, 11)
    }

    func test_init_returnsNilWhenFieldMissing() {
        let cbor = CBORValue.map([("s", .text("HomeWiFi")), ("r", .negative(-55))])
        XCTAssertNil(DiscoveredWiFiNetwork(cbor: cbor))
    }
}
