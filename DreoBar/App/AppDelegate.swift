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

    /// Stops macOS opening a window just because the app was activated.
    ///
    /// This app lives in the menu bar and has exactly one window scene, the
    /// pairing wizard. Triggering `dreobar://toggle` activates the app, and
    /// without this the activation was answered by opening that wizard, so
    /// pressing the hotkey toggled the fan and threw up a setup dialog at the
    /// same time.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The wizard's frame gets persisted, and a restored frame is enough
        // for macOS to bring the window back on a later launch. Nothing here
        // is worth restoring: the menu bar is the entry point.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let model = appModel else { return }
        guard urls.contains(where: { $0.scheme == "dreobar" && $0.host == "toggle" }) else { return }
        Task { @MainActor in
            model.toggleLastSelectedDevicePower()
        }
    }
}
