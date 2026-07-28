import Foundation

/// A pairing failure translated into something the person in front of the
/// Mac can act on. Raw errors like `peripheralNotFound` say what the code
/// saw; these say what to do about it.
struct PairingFailure: Equatable {
    enum Recovery: Equatable {
        /// Retry the step that failed.
        case retry
        /// Go back and pick a network again, e.g. after a wrong password.
        case chooseNetworkAgain
        /// Open a System Settings pane, because nothing in this app can fix it.
        case openSettings(url: String, label: String)
        /// Nothing to retry: the Mac can't do Bluetooth at all.
        case none
    }

    let title: String
    let detail: String
    let recovery: Recovery

    static let notSignedIn = PairingFailure(
        title: "Sign in first",
        detail: "A new fan has to be linked to your Dreo account while it joins WiFi, "
            + "so sign in from the menu bar before pairing.",
        recovery: .none
    )

    init(title: String, detail: String, recovery: Recovery) {
        self.title = title
        self.detail = detail
        self.recovery = recovery
    }

    init(_ error: Error) {
        if case DreoBLEError.bluetoothUnavailable(let availability) = error {
            self = Self.bluetooth(availability)
        } else {
            self = Self.pairing(error)
        }
    }

    private static func bluetooth(_ availability: DreoBLEError.BluetoothAvailability) -> PairingFailure {
        switch availability {
        case .poweredOff:
            PairingFailure(
                title: "Bluetooth is off",
                detail: "Pairing talks to the fan over Bluetooth. Turn it on, then try again.",
                recovery: .openSettings(
                    url: "x-apple.systempreferences:com.apple.BluetoothSettings",
                    label: "Open Bluetooth Settings"
                )
            )
        case .unauthorized:
            PairingFailure(
                title: "DreoBar can't use Bluetooth",
                detail: "macOS is blocking Bluetooth access for this app. Allow it under "
                    + "Privacy & Security, then try again.",
                recovery: .openSettings(
                    url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
                    label: "Open Privacy Settings"
                )
            )
        case .unsupported:
            PairingFailure(
                title: "No Bluetooth on this Mac",
                detail: "Pairing a new fan needs Bluetooth, so it has to be done from the Dreo phone app.",
                recovery: .none
            )
        }
    }

    private static func pairing(_ error: Error) -> PairingFailure {
        switch error {
        case DreoBLEError.peripheralNotFound:
            PairingFailure(
                title: "No fan in pairing mode",
                detail: "Check the WiFi light is still blinking and the fan is within a few metres "
                    + "of this Mac, then try again.",
                recovery: .retry
            )
        case DreoBLEError.joinRejected, DreoBLEError.deviceRejected:
            PairingFailure(
                title: "The fan couldn't join that network",
                detail: "That usually means the password was wrong, or the network is 5 GHz only. "
                    + "These fans only join 2.4 GHz networks.",
                recovery: .chooseNetworkAgain
            )
        case DreoBLEError.joinTimedOut:
            PairingFailure(
                title: "The fan stopped responding",
                detail: "It never reported whether it joined. Put it back into pairing mode and try again.",
                recovery: .retry
            )
        default:
            PairingFailure(
                title: "Pairing didn't finish",
                detail: "Something went wrong talking to the fan. Put it back into pairing mode and try again.",
                recovery: .retry
            )
        }
    }
}
