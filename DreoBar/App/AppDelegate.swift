import AppKit
import KeyboardShortcuts

/// Owns the two ways to toggle fan power that don't go through the menu bar
/// dropdown: the global keyboard shortcut and the `dreobar://toggle` URL
/// scheme (for iCUE's "Launch Application" action, once iCUE is working).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appModel: AppModel?

    func configure(appModel: AppModel) {
        self.appModel = appModel
        let model = appModel
        KeyboardShortcuts.onKeyUp(for: .toggleFanPower) {
            Task { @MainActor in
                model.toggleLastSelectedDevicePower()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let model = appModel else { return }
        guard urls.contains(where: { $0.scheme == "dreobar" && $0.host == "toggle" }) else { return }
        Task { @MainActor in
            model.toggleLastSelectedDevicePower()
        }
    }
}
