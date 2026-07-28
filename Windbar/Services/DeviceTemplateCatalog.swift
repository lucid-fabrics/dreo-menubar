import Foundation
import os

/// Control schemas for Dreo models the server declines to describe.
///
/// Older products ship a full `controlsConf` in the device-list response,
/// which the app renders generically. Newer ones send only
/// `{"template": "<model>"}` and keep the real layout inside the official
/// app. `DeviceTemplates.json` is that layout, lifted from the vendor app's
/// bundled `app_config.json` with its labels already resolved to English,
/// and reshaped into the same `ControlSchema` the server sends, so both
/// paths render through identical code.
enum DeviceTemplateCatalog {
    private static let logger = Logger(subsystem: "com.lucidfabrics.windbar", category: "DeviceTemplateCatalog")

    private static let catalog: [String: ControlSchema] = {
        guard let url = Bundle.main.url(forResource: "DeviceTemplates", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.warning("DeviceTemplates.json missing from bundle")
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: ControlSchema].self, from: data)
        } catch {
            logger.warning("DeviceTemplates.json unreadable: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }()

    /// Bundled schema for a model, or nil when this app has no template for it.
    static func schema(forModel model: String) -> ControlSchema? {
        catalog[model]
    }

    static var modelCount: Int { catalog.count }
}
