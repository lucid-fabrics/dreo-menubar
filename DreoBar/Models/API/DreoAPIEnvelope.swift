import Foundation

/// Every Dreo REST response is wrapped in `{code, msg, data}`. `code == 0`
/// means success; anything else carries an error message in `msg`.
struct DreoAPIEnvelope<Payload: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: Payload?

    enum CodingKeys: String, CodingKey {
        case code, msg, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        // `msg` is normally a string, but some failures return a bare error
        // number instead. A failed envelope still has to decode, otherwise
        // the code it carries never reaches the caller.
        if let text = try? container.decode(String.self, forKey: .msg) {
            msg = text
        } else if let number = try? container.decode(Int.self, forKey: .msg) {
            msg = String(number)
        } else {
            msg = nil
        }
        data = try? container.decode(Payload.self, forKey: .data)
    }
}

/// For endpoints that report success purely through `code`, with no payload.
struct DreoEmptyPayload: Decodable {}
