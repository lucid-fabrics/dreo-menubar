import Foundation

enum DreoBLEError: Error, Equatable, Sendable {
    case notConnected
    case peripheralNotFound
    case serviceNotFound
    case characteristicNotFound
    case joinTimedOut
    case joinRejected
    case deviceRejected(code: Data)
    /// Bluetooth itself can't be used: switched off, denied to this app, or
    /// missing. Distinct from "no fan found" so the UI can tell the user
    /// something they can actually act on.
    case bluetoothUnavailable(BluetoothAvailability)

    enum BluetoothAvailability: Equatable, Sendable {
        case poweredOff
        case unauthorized
        case unsupported
    }
}
