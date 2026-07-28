import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Last-used device:", name: .toggleFanPower)
            } header: {
                Label("Shortcut", systemImage: "keyboard")
            } footer: {
                Text("Toggles whichever device you touched last. Each fan can also have its own key, "
                     + "under More Options on that fan in the menu.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            } header: {
                Label("Startup", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 260)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
