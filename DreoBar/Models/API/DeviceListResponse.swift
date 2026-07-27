import Foundation

/// `data` payload of `GET /api/v2/user-device/device/list`.
struct DeviceListData: Decodable {
    let list: [DeviceListEntry]

    enum CodingKeys: String, CodingKey {
        case list
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // One unparseable device must not hide every other device on the
        // account.
        list = container.decodeLossyArray(DeviceListEntry.self, forKey: .list)
    }
}

struct DeviceListEntry: Decodable {
    let serialNumber: String
    let deviceName: String
    let model: String
    let controlsConf: ControlSchema?

    enum CodingKeys: String, CodingKey {
        case serialNumber = "sn"
        case deviceName, model, controlsConf
    }
}
