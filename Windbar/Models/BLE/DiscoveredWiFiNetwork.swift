import Foundation

/// One WiFi network the fan can see, decoded from a `"wl"` notification's
/// `d.l[]` array: `{"s": ssid, "r": rssi, "a": authType, "c": channel}`,
/// confirmed by live capture of a real pairing session (2026-07-27). The
/// fan streams these in small batches (including empty ones) as its scan
/// progresses; it doesn't report a BSSID.
struct DiscoveredWiFiNetwork: Identifiable, Equatable, Hashable, Sendable {
    let ssid: String
    let rssi: Int
    let authType: Int
    let channel: Int

    var id: String { ssid }

    init?(cbor: CBORValue) {
        guard let ssid = cbor["s"]?.stringValue,
              let rssi = cbor["r"]?.intValue,
              let authType = cbor["a"]?.intValue,
              let channel = cbor["c"]?.intValue else { return nil }
        self.ssid = ssid
        self.rssi = rssi
        self.authType = authType
        self.channel = channel
    }
}
