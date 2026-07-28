import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                if appModel.devices.isEmpty {
                    Text("Your devices will appear here once they have loaded.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.devices) { device in
                        KeyboardShortcuts.Recorder(
                            device.deviceName,
                            name: .togglePower(deviceSerialNumber: device.serialNumber)
                        )
                    }
                }
            } header: {
                Label("Per-device shortcuts", systemImage: "fan")
            } footer: {
                Text("Each fan gets its own key, so you can reach one directly without opening the menu.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                KeyboardShortcuts.Recorder("Last-used device:", name: .toggleFanPower)
            } header: {
                Label("Shortcut", systemImage: "keyboard")
            } footer: {
                Text("Toggles whichever device you touched last. Useful if you mostly use one fan.")
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
        .frame(width: 420)
        .frame(minHeight: 340, maxHeight: 540)
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
