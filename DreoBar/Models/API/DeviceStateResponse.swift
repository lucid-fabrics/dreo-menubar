import Foundation

/// `data` payload of `GET /api/user-device/device/state`. Each entry in
/// `mixed` is either a raw scalar or `{"state": <value>, "timestamp": ...}`;
/// `MixedStateEntry` normalizes both shapes to a single `DreoValue`.
///
/// A few fields (`timeron`/`timeroff`) carry a nested object as their state
/// (e.g. `{"du": 0, "ts": ...}`) that `DreoValue` can't represent. Decoding
/// `mixed` key-by-key with `try?` skips just those fields instead of
/// aborting the whole dictionary, which previously left `device.state`
/// completely empty whenever any single field had an unsupported shape.
struct DeviceStateData: Decodable {
    let flattened: [String: DreoValue]

    private enum CodingKeys: String, CodingKey {
        case mixed
    }

    private struct DynamicCodingKeys: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mixedContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .mixed)

        var result: [String: DreoValue] = [:]
        for key in mixedContainer.allKeys {
            if let entry = try? mixedContainer.decode(MixedStateEntry.self, forKey: key) {
                result[key.stringValue] = entry.value
            }
        }
        flattened = result
    }
}

struct MixedStateEntry: Decodable {
    let value: DreoValue

    private struct StateWrapper: Decodable {
        let state: DreoValue
    }

    init(from decoder: Decoder) throws {
        if let wrapper = try? StateWrapper(from: decoder) {
            value = wrapper.state
        } else {
            value = try DreoValue(from: decoder)
        }
    }
}
