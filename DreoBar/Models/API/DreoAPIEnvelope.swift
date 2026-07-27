import Foundation

/// Every Dreo REST response is wrapped in `{code, msg, data}`. `code == 0`
/// means success; anything else carries an error message in `msg`.
struct DreoAPIEnvelope<Payload: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: Payload?
}
