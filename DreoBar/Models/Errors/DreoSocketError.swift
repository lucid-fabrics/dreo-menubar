import Foundation

enum DreoSocketError: Error, Equatable, Sendable {
    case notConnected
    case ackTimeout
}
