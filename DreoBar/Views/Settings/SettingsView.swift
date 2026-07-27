import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle fan power:", name: .toggleFanPower)
            } header: {
                Label("Shortcut", systemImage: "keyboard")
            } footer: {
                Text("Toggles power on your last-used device from anywhere, even while DreoBar is in the background.")
                    .font(.system(size: 11))
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
        .frame(width: 380, height: 220)
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
