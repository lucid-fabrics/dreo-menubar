import Foundation

enum DreoBLEError: Error, Equatable, Sendable {
    case notConnected
    case peripheralNotFound
    case serviceNotFound
    case characteristicNotFound
    case joinTimedOut
    case joinRejected
    case deviceRejected(code: Data)
}
