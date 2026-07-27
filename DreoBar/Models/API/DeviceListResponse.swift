import Foundation

/// `data` payload of `GET /api/v2/user-device/device/list`.
struct DeviceListData: Decodable {
    let list: [DeviceListEntry]
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
