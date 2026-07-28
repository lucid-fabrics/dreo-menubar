import Foundation
import os

/// English text for the localisation keys the Dreo API sends instead of
/// readable labels.
///
/// Older devices return raw keys in their `controlsConf`, so a control comes
/// across as `device_control_panelsound` rather than "Panel Sound". Splitting
/// those on underscores gets close but not there: that key has no separator
/// between the two words, so it renders as "Panelsound", and
/// `device_fans_mode_straight` reads as "Straight" when the official app calls
/// it "Normal".
///
/// `Labels.json` is the vendor app's own English string table, cut down to the
/// keys that appear in device schemas, so labels match what the Dreo app shows.
enum DeviceLabels {
    private static let logger = Logger(subsystem: "com.dreobar", category: "DeviceLabels")

    private static let table: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Labels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            logger.warning("Labels.json missing or unreadable")
            return [:]
        }
        return decoded
    }()

    /// The English label for a key, or nil when this app has no entry, in
    /// which case the caller falls back to tidying the key itself.
    static func text(forKey key: String) -> String? {
        table[key]
    }

    static var count: Int { table.count }
}
