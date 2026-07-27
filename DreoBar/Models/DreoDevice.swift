import Foundation

/// A single Dreo device plus its live state, as reported by the device-state
/// REST call and kept current by websocket push updates.
struct DreoDevice: Identifiable, Equatable, Sendable {
    let serialNumber: String
    let deviceName: String
    let model: String
    let controlsConf: ControlSchema?
    var state: [String: DreoValue]

    var id: String { serialNumber }

    init(
        serialNumber: String,
        deviceName: String,
        model: String,
        controlsConf: ControlSchema?,
        state: [String: DreoValue] = [:]
    ) {
        self.serialNumber = serialNumber
        self.deviceName = deviceName
        self.model = model
        self.controlsConf = controlsConf
        self.state = state
    }

    /// Some Dreo devices report power as `poweron`, others as `fanon`.
    var powerKey: String {
        state["poweron"] != nil ? "poweron" : "fanon"
    }

    var isOn: Bool {
        state[powerKey]?.boolValue ?? false
    }

    mutating func apply(_ updates: [String: DreoValue]) {
        for (key, value) in updates {
            state[key] = value
        }
    }
}
