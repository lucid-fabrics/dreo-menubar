import Foundation

/// A partial state push from the device websocket (`reported` in the
/// Dreo protocol). Only the keys that actually changed are present.
struct DreoStateUpdate: Equatable, Sendable {
    let serialNumber: String
    let changes: [String: DreoValue]
}
