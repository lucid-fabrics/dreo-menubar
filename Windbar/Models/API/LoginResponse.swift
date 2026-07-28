import Foundation

/// `data` payload of `POST /api/oauth/login`.
struct LoginData: Decodable {
    let accessToken: String
    let region: String
    /// Numeric account id. BLE provisioning has to hand this to a new fan
    /// so it binds itself to the right account (the `pd` message).
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case region
        case userId = "userid"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        region = try container.decode(String.self, forKey: .region)
        // Sent as a bare JSON number, well past Int32 range; decode either shape.
        if let numeric = try? container.decode(UInt64.self, forKey: .userId) {
            userId = String(numeric)
        } else {
            userId = try? container.decode(String.self, forKey: .userId)
        }
    }
}
