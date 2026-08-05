import Foundation

/// Command envelopes written to `DreoBLE.writeCharacteristic` and the
/// response envelopes decoded from `DreoBLE.notifyCharacteristic`
/// notifications. Confirmed against a real pairing by live Frida capture
/// of the official Dreo Android app (2026-07-27): every message is CBOR,
/// `{"t": <type>, "v": <3-byte version>, "d": <payload>}` (the final "cw"
/// write omits "v", matching the capture byte-for-byte).
enum DreoBLEMessage {
    private static let protocolVersion = Data([0x00, 0x00, 0x01])

    static func setTime(_ date: Date = Date()) -> Data {
        encode(type: "st", data: .map([("t", .unsigned(UInt64(date.timeIntervalSince1970)))]))
    }

    /// Tells the fan which account to report to and which endpoints to use
    /// once it's online. Only send this when `userId` is a real, verified
    /// account id: a wrong value would bind the device to the wrong account.
    static func provisionDomains(userId: UInt64, deviceAPIHost: String) -> Data {
        let accountMap = CBORValue.map([
            ("a", .map([("h", .text("1")), ("p", .text("/api/device/activate/emq"))])),
            ("o", .map([("h", .text("1")), ("p", .text("/api/oauth/login"))])),
            ("r", .map([("h", .text("1")), ("p", .text("/api/device/rebind/user"))]))
        ])
        let payload = CBORValue.map([
            ("a", accountMap),
            ("h", .map([("1", .text(deviceAPIHost))])),
            ("u", .unsigned(userId))
        ])
        return encode(type: "pd", data: payload)
    }

    /// Asks the fan to report its identity. The official app always sends
    /// this right after `st` and before provisioning; the fan replies `ri`.
    static func readDeviceInfo() -> Data {
        let fields: [CBORValue] = [.text("sn"), .text("fv"), .text("pi"), .text("ps"), .text("ms"), .text("tk")]
        return encode(type: "rd", data: .map([("i", .array(fields))]))
    }

    static func requestWiFiScan(channels: ClosedRange<Int> = 1...13, durationMs: Int = 300) -> Data {
        let payload = CBORValue.map([
            ("o", .array(channels.map { .unsigned(UInt64($0)) })),
            ("t", .unsigned(UInt64(durationMs)))
        ])
        return encode(type: "rw", data: payload)
    }

    /// Password goes over BLE in cleartext, matching the real app: BLE's
    /// own link-layer pairing is the only protection here, there's no
    /// app-layer encryption in this protocol. Field order matches a live
    /// capture (2026-07-27) byte-for-byte: the fan's firmware parses this
    /// map positionally, not by key, so order here isn't cosmetic.
    /// `includeSelfCheck: false` drops the `scc` connectivity-probe block
    /// and sets `sc` to 0, shrinking the message from 213 to ~78 bytes. The
    /// fan then joins WiFi without probing the internet afterwards. This is
    /// a fallback, not the default: CoreBluetooth (unlike Android) offers no
    /// way to raise the ATT MTU, so an oversized write gets split into ATT
    /// prepare/execute writes, which a peripheral's firmware may reject.
    /// Measured on the hardware here macOS negotiates 515, so the full
    /// 213-byte message fits in one write and the shrink isn't needed. Kept
    /// for peripherals or Macs that negotiate less generously.
    static func connectWiFi(
        network: DiscoveredWiFiNetwork,
        password: String,
        includeSelfCheck: Bool = true
    ) -> Data {
        var payload: [(String, CBORValue)] = [
            ("a", .unsigned(UInt64(network.authType))),
            ("b", .unsigned(0)),
            ("c", .unsigned(UInt64(network.channel))),
            ("m", .map([("ca", .unsigned(0)), ("cm", .unsigned(0)), ("da", .unsigned(0))])),
            ("p", .text(password)),
            ("s", .text(network.ssid)),
            ("t", .map([("ca", .unsigned(60000)), ("cm", .unsigned(60000)), ("da", .unsigned(30000))])),
            ("sc", .unsigned(includeSelfCheck ? 1 : 0))
        ]
        if includeSelfCheck {
            payload.append(("scc", .map([
                ("dm", .array([
                    .text("http://www.google.com"),
                    .text("http://www.youtube.com"),
                    .text("http://www.microsoft.com")
                ])),
                ("ip", .array([.text("172.217.25.14"), .text("142.250.66.78")])),
                ("pn", .unsigned(100)),
                ("ps", .unsigned(64)),
                ("pt", .unsigned(1000)),
                ("pmt", .unsigned(20000))
            ])))
        }
        return CBOR.encode(.map([("d", .map(payload)), ("t", .text("cw"))]))
    }

    private static func encode(type: String, data: CBORValue) -> Data {
        CBOR.encode(.map([("d", data), ("t", .text(type)), ("v", .bytes(protocolVersion))]))
    }
}

/// A decoded response/report notification from the fan.
enum DreoBLENotification: Equatable {
    case wifiNetworks([DiscoveredWiFiNetwork])
    /// Sent repeatedly while the fan works through joining; `stage` is its
    /// internal state number, useful only as proof it is still progressing.
    case connectProgress(stage: Int)
    case connectFinished(success: Bool)
    case error(code: Data)
    case other(type: String)

    init?(data: Data) {
        guard let envelope = try? CBOR.decode(data), let type = envelope["t"]?.stringValue else { return nil }
        // "ee" notifications don't nest their payload under "d" like every
        // other message type: the error code sits directly under "e" on
        // the envelope itself (confirmed live, 2026-07-27).
        if type == "ee" {
            self = .error(code: envelope["e"]?.dataValue ?? Data())
            return
        }

        let payload = envelope["d"]
        switch type {
        case "wl":
            let networks = payload?["l"]?.arrayValue?.compactMap(DiscoveredWiFiNetwork.init(cbor:)) ?? []
            self = .wifiNetworks(networks)
        case "cw":
            self = .connectProgress(stage: payload?["c"]?.intValue ?? 0)
        case "cf":
            self = .connectFinished(success: payload?["r"]?.boolValue ?? false)
        default:
            self = .other(type: type)
        }
    }
}
