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

    /// Handles `dreobar://toggle`, and `dreobar://toggle?device=<serial>` for
    /// a specific fan.
    ///
    /// The per-device form exists because macro keys cannot be recorded as
    /// shortcuts: a Corsair G-key, a Stream Deck button or an Elgato pedal is
    /// swallowed by its own software and never reaches this app as a
    /// keystroke. Those tools can all launch a URL, so this is how they aim
    /// at one fan instead of whichever was touched last.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let model = appModel else { return }

        for url in urls where url.scheme == "dreobar" && url.host == "toggle" {
            let serialNumber = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "device" }?
                .value

            Task { @MainActor in
                if let serialNumber, !serialNumber.isEmpty {
                    model.togglePower(serialNumber: serialNumber)
                } else {
                    model.toggleLastSelectedDevicePower()
                }
            }
        }
    }
}
