import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var lastSelectedDeviceSerialNumber: String?

    static let `default` = AppSettings(lastSelectedDeviceSerialNumber: nil)
}
