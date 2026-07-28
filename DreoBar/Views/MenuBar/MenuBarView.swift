import AppKit
import SwiftUI

struct MenuBarView: View {
    let appModel: AppModel

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch appModel.launchState {
            case .loading:
                StatusPlaceholder(isBusy: true, message: "Connecting to your devices…")
            case .needsLogin:
                LoginView(appModel: appModel)
            case .ready:
                ready
            }
        }
        .frame(width: Theme.Metric.popoverWidth)
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            if appModel.devices.isEmpty {
                StatusPlaceholder(
                    systemImage: "fan.slash",
                    message: "No Dreo devices on this account yet."
                )
            } else {
                VStack(spacing: Theme.Space.snug) {
                    ForEach(appModel.devices) { device in
                        DeviceControlView(appModel: appModel, device: device)
                    }
                }
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.top, Theme.Metric.gutter)
            }

            if let errorMessage = appModel.errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .padding(.horizontal, Theme.Metric.gutter)
            }

            Divider()
                .padding(.horizontal, Theme.Metric.gutter)

            footer
        }
        .padding(.bottom, Theme.Space.snug)
    }

    private var footer: some View {
        VStack(spacing: 1) {
            HoverRow(
                icon: "arrow.clockwise",
                title: "Refresh Devices",
                isLoading: appModel.isRefreshingDevices
            ) {
                Task { await appModel.refreshDevices() }
            }
            .keyboardShortcut("r")

            HoverRow(icon: "plus.circle", title: "Add a Device…") {
                // Order matters: activating before the window exists leaves
                // it behind whatever app was frontmost.
                openWindow(id: "add-device")
                NSApp.activate(ignoringOtherApps: true)
            }

            HoverRow(icon: "gearshape", title: "Preferences…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",")

            HoverRow(icon: "power", title: "Quit DreoBar") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, Theme.Space.tight)
    }
}
