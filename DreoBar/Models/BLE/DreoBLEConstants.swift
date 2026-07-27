import CoreBluetooth

/// GATT UUIDs for the Dreo "HeFi" BLE provisioning protocol, confirmed by
/// live Frida capture of a real pairing session against a Pilot Max tower
/// fan (2026-07-27). The service follows the standard 16-bit-UUID base
/// pattern; it's a custom vendor service, not a Bluetooth SIG assigned one.
///
/// An earlier static-analysis pass had this wrong: it found service 0xFFB4
/// with an RSA-encrypted fixed-byte-layout payload, but that code path
/// belongs to a different BLE SDK the Dreo app also ships (`Constant
/// .SDKType.P7`) that this fan doesn't use. This fan speaks "HeFi": plain
/// CBOR envelopes, password sent in cleartext (see `DreoBLEMessage`).
enum DreoBLE {
    nonisolated(unsafe) static let service = CBUUID(string: "0000ffff-0000-1000-8000-00805f9b34fb")

    /// App writes CBOR command envelopes here.
    nonisolated(unsafe) static let writeCharacteristic = CBUUID(string: "00009b01-0000-1000-8000-00805f9b34fb")

    /// Subscribe here once after connecting; every response/report (device
    /// info, WiFi scan results, connect progress, connect result) arrives
    /// as a CBOR envelope on this single characteristic, demultiplexed by
    /// its `"t"` field rather than by characteristic.
    nonisolated(unsafe) static let notifyCharacteristic = CBUUID(string: "00009b02-0000-1000-8000-00805f9b34fb")
}
