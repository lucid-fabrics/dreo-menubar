import SwiftUI

/// Pairs a new fan onto WiFi over Bluetooth LE, reimplementing the
/// official Dreo app's protocol (see `DreoBLEPairingService`). No manual
/// WiFi-network-joining step needed, BLE replaces that entirely.
struct AddDeviceView: View {
    private enum Step {
        case connecting
        case scanningNetworks
        case pickNetwork([DiscoveredWiFiNetwork])
        case enterPassword(DiscoveredWiFiNetwork)
        case sending(DiscoveredWiFiNetwork)
        case success
        case failed(String)
    }

    let appModel: AppModel

    @State private var step: Step = .connecting
    @State private var password = ""
    @State private var bleService = DreoBLEPairingService()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            header

            switch step {
            case .connecting:
                statusView(message: "Looking for a fan in pairing mode…")
            case .scanningNetworks:
                statusView(message: "Asking the fan what WiFi networks it can see…")
            case .pickNetwork(let networks):
                pickNetworkView(networks: networks)
            case .enterPassword(let network):
                enterPasswordView(network: network)
            case .sending(let network):
                statusView(message: "Sending WiFi credentials to \(network.ssid.isEmpty ? "the fan" : network.ssid)…")
            case .success:
                successView
            case .failed(let message):
                failedView(message: message)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Space.loose)
        .frame(width: 420, height: 420, alignment: .top)
        .task {
            await connectAndScan()
        }
        .onDisappear {
            bleService.disconnect()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text("Add a Device")
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func statusView(message: String) -> some View {
        StatusPlaceholder(isBusy: true, message: message)
    }

    private func pickNetworkView(networks: [DiscoveredWiFiNetwork]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Which network should the fan join?")
                .font(Theme.Font.body)
                .foregroundStyle(.secondary)

            if networks.isEmpty {
                InlineErrorBanner(message: "The fan didn't report any networks it can see. Try scanning again.")
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(networks.sorted(by: { $0.rssi > $1.rssi })) { network in
                            HoverRow(icon: signalIcon(for: network.rssi), title: network.ssid) {
                                step = .enterPassword(network)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }

            Button("Scan Again") {
                Task { await scanNetworks() }
            }
        }
    }

    /// The fan reports each network's signal, so show it rather than a flat
    /// list: the one it hears best is the one most likely to work.
    private func signalIcon(for rssi: Int) -> String {
        switch rssi {
        case (-60)...: return "wifi"
        case (-75)..<(-60): return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }

    private func enterPasswordView(network: DiscoveredWiFiNetwork) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(spacing: Theme.Space.tight) {
                Image(systemName: "wifi")
                Text(network.ssid)
                    .font(.system(size: 13, weight: .semibold))
            }

            SecureField("WiFi Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Send to Fan") {
                Task { await send(network: network) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty)

            Button("Choose a Different Network") {
                Task { await scanNetworks() }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            Text("The fan accepted the credentials and is joining your WiFi.")
                .font(Theme.Font.body)
                .multilineTextAlignment(.center)
            Text("Give it a minute, then hit Refresh Devices in the menu bar.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private func failedView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineErrorBanner(message: message)
            Button("Try Again") {
                Task { await connectAndScan() }
            }
        }
    }

    private func connectAndScan() async {
        step = .connecting
        do {
            try await bleService.connectToFan()
            // Tell the fan which account to bind to before asking it to join
            // WiFi; without this the fan refuses the join request.
            if let session = await appModel.currentSession(), let userId = session.userId {
                try await bleService.provisionAccount(userId: userId, deviceAPIHost: session.deviceAPIHost)
            }
            await scanNetworks()
        } catch {
            step = .failed("Couldn't find a fan in pairing mode. Hold Oscillation for 5s and try again.")
        }
    }

    private func scanNetworks() async {
        step = .scanningNetworks
        let networks = await (try? bleService.scanWiFiNetworks()) ?? []
        step = .pickNetwork(networks)
    }

    private func send(network: DiscoveredWiFiNetwork) async {
        step = .sending(network)
        do {
            try await bleService.sendCredentials(network: network, password: password)
            step = .success
        } catch {
            step = .failed("The fan rejected the credentials (\(error)). Double check the password and try again.")
        }
    }
}
