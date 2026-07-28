import AppKit
import SwiftUI

/// Guided setup for a new fan, start to finish: put the fan into pairing
/// mode, find it over Bluetooth, pick a network, hand over the password,
/// watch it join.
///
/// The first screen matters most. Pairing only works while the fan is
/// advertising, which it does for a short window after a physical button
/// press, so the flow explains that and waits to be told the fan is ready
/// rather than silently scanning and timing out.
struct AddDeviceView: View {
    private enum Step: Equatable {
        case prepare
        case connecting
        case chooseNetwork([DiscoveredWiFiNetwork])
        case password(DiscoveredWiFiNetwork)
        case joining(DiscoveredWiFiNetwork)
        case done
        case failed(PairingFailure)

        /// Position in the visible progress, or nil for terminal screens.
        var dotIndex: Int? {
            switch self {
            case .prepare: 0
            case .connecting: 1
            case .chooseNetwork: 2
            case .password, .joining: 3
            case .done, .failed: nil
            }
        }
    }

    let appModel: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .prepare
    @State private var password = ""
    @State private var revealPassword = false
    @State private var hasStartedJoining = false
    @State private var bleService = DreoBLEPairingService()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            header

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            footer
        }
        .padding(Theme.Space.loose)
        .frame(width: 440, height: 470, alignment: .top)
        .onAppear(perform: bringToFront)
        .onDisappear { bleService.disconnect() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Space.snug) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: Theme.Space.snug)
            if let index = step.dotIndex {
                StepDots(total: 4, current: index)
            }
        }
    }

    private var title: String {
        switch step {
        case .prepare: "Add a Device"
        case .connecting: "Looking for your fan"
        case .chooseNetwork: "Choose a network"
        case .password(let network): network.ssid
        case .joining: "Joining WiFi"
        case .done: "All set"
        case .failed(let failure): failure.title
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .prepare:
            PairingInstructions()
        case .connecting:
            StatusPlaceholder(isBusy: true, message: "Searching for a fan in pairing mode nearby…")
        case .chooseNetwork(let networks):
            NetworkPicker(networks: networks) { network in
                password = ""
                step = .password(network)
            }
        case .password(let network):
            passwordStep(network)
        case .joining:
            StatusPlaceholder(
                isBusy: true,
                message: hasStartedJoining
                    ? "The fan is connecting to your network. This can take up to a minute."
                    : "Sending the network details to your fan…"
            )
        case .done:
            PairingSuccess()
        case .failed(let failure):
            failedStep(failure)
        }
    }

    // MARK: - Steps

    private func passwordStep(_ network: DiscoveredWiFiNetwork) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Enter the password for this network. It is sent straight to the fan.")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Space.tight) {
                Group {
                    if revealPassword {
                        TextField("Network password", text: $password)
                    } else {
                        SecureField("Network password", text: $password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .onSubmit { join(network) }

                Button {
                    revealPassword.toggle()
                } label: {
                    Image(systemName: revealPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(revealPassword ? "Hide password" : "Show password")
            }
        }
    }

    private func failedStep(_ failure: PairingFailure) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(failure.detail)
                .font(Theme.Font.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .openSettings(let url, let label) = failure.recovery {
                Button(label) {
                    if let settings = URL(string: url) { NSWorkspace.shared.open(settings) }
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: Theme.Space.snug) {
            switch step {
            case .prepare:
                Button("Cancel") { dismiss() }
                Spacer()
                Button("The Light Is Blinking") { start() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)

            case .connecting, .joining:
                Button("Cancel") {
                    bleService.disconnect()
                    step = .prepare
                }
                Spacer()

            case .chooseNetwork:
                Button("Back") { step = .prepare }
                Spacer()
                Button("Scan Again") { Task { await scanNetworks() } }

            case .password(let network):
                Button("Back") { Task { await scanNetworks() } }
                Spacer()
                Button("Join Network") { join(network) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)

            case .done:
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)

            case .failed(let failure):
                Button("Close") { dismiss() }
                Spacer()
                switch failure.recovery {
                case .retry, .openSettings:
                    Button("Try Again") { step = .prepare }
                        .buttonStyle(.borderedProminent)
                case .chooseNetworkAgain:
                    Button("Choose Network") { Task { await scanNetworks() } }
                        .buttonStyle(.borderedProminent)
                case .none:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Flow

    /// A menu bar app has no Dock icon to click, so a newly opened setup
    /// window can end up behind whatever app was in front. Raise it once it
    /// actually exists.
    private func bringToFront() {
        // macOS answers app activation by opening this window scene, so
        // firing dreobar://toggle used to toggle the fan and raise the setup
        // wizard at the same time. Only stay open if the menu actually asked.
        guard appModel.hasRequestedPairing else {
            dismiss()
            return
        }
        appModel.hasRequestedPairing = false

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows
                .first { $0.title == "Add a Device" }?
                .makeKeyAndOrderFront(nil)
        }
    }

    private func start() {
        Task {
            step = .connecting
            do {
                // The fan has to be told which account it belongs to before
                // it will accept a network, so refuse early if there is no
                // session rather than failing deep in the flow.
                guard let session = await appModel.currentSession(), let userId = session.userId else {
                    step = .failed(.notSignedIn)
                    return
                }
                try await bleService.connectToFan()
                try await bleService.provisionAccount(userId: userId, deviceAPIHost: session.deviceAPIHost)
                await scanNetworks()
            } catch {
                step = .failed(PairingFailure(error))
            }
        }
    }

    private func scanNetworks() async {
        step = .connecting
        do {
            let networks = try await bleService.scanWiFiNetworks()
            step = .chooseNetwork(networks.sorted { $0.rssi > $1.rssi })
        } catch {
            step = .failed(PairingFailure(error))
        }
    }

    private func join(_ network: DiscoveredWiFiNetwork) {
        guard !password.isEmpty else { return }
        hasStartedJoining = false
        bleService.onJoinProgress = { _ in hasStartedJoining = true }
        step = .joining(network)

        Task {
            do {
                try await bleService.sendCredentials(network: network, password: password)
                password = ""
                step = .done
                await appModel.refreshDevices()
            } catch {
                step = .failed(PairingFailure(error))
            }
            bleService.onJoinProgress = nil
        }
    }

}
