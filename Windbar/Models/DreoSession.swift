import Foundation

/// The result of a successful login: the bearer token plus which regional
/// host (`"us"` or `"eu"`) it's valid against. Handed to `DreoSocketService`
/// to open the matching websocket host.
struct DreoSession: Equatable, Sendable {
    let accessToken: String
    let regionHost: String
    /// Numeric account id from the login response, used by BLE pairing to
    /// bind a new fan to this account. Nil if the server omitted it.
    var userId: UInt64?

    /// Device-facing API host the fan itself should call once online. This
    /// is a different host from the app's own API.
    var deviceAPIHost: String { "https://device-api-\(regionHost).dreo-cloud.com" }
}
