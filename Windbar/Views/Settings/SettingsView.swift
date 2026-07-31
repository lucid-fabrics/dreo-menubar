import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isConfirmingSignOut = false

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

            Section {
                Button("Sign Out…", role: .destructive) { isConfirmingSignOut = true }
                    .disabled(appModel.launchState != .ready)
            } header: {
                Label("Account", systemImage: "person.crop.circle")
            } footer: {
                Text("Removes your Dreo password from the macOS Keychain and disconnects. "
                     + "You will need to sign in again to control your fans.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 360)
        // Confirm first: this discards a password the user may not remember, and there
        // is no undo.
        .confirmationDialog("Sign out of Dreo?", isPresented: $isConfirmingSignOut) {
            Button("Sign Out", role: .destructive) {
                Task { await appModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your password will be removed from the Keychain and your fans will "
                 + "disappear from the menu bar until you sign in again.")
        }
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
