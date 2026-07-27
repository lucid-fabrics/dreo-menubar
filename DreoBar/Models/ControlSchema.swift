import Foundation

/// Mirrors the `controlsConf` object the Dreo API returns per device. This is
/// the server's own UI schema (modes, speed range, oscillation angles, etc),
/// so the app renders controls generically from it instead of hardcoding
/// behavior per model.
struct ControlSchema: Codable, Equatable, Sendable {
    var control: [ControlSection]
    var preference: [ControlSection]

    /// True when the server sent no renderable controls at all. Happens for
    /// a device that was only just provisioned, whose `controlsConf` comes
    /// back holding nothing but a `template` field.
    var isEmpty: Bool { control.isEmpty && preference.isEmpty }

    init(control: [ControlSection] = [], preference: [ControlSection] = []) {
        self.control = control
        self.preference = preference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        control = container.decodeLossyArray(ControlSection.self, forKey: .control)
        preference = container.decodeLossyArray(ControlSection.self, forKey: .preference)
    }
}

struct ControlSection: Codable, Equatable, Identifiable, Sendable {
    let rawId: String?
    let type: String
    let title: String?
    let cmd: String?
    let items: [ControlItem]?

    var id: String { rawId ?? type }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case type, title, cmd, items
    }
}

struct ControlItem: Codable, Equatable, Identifiable, Sendable {
    let text: String
    let cmd: String
    let value: DreoValue

    var id: String { "\(cmd)_\(value)" }
}
