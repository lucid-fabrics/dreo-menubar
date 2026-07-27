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
                loadingState
            case .needsLogin:
                LoginView(appModel: appModel)
            case .ready:
                deviceList
            }
        }
        .frame(width: 300)
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Connecting…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "fan.slash")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text("No Dreo devices found")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appModel.devices.isEmpty {
                emptyState
            } else {
                ForEach(Array(appModel.devices.enumerated()), id: \.element.id) { index, device in
                    DeviceControlView(appModel: appModel, device: device)
                    if index < appModel.devices.count - 1 {
                        Divider().padding(.horizontal, 14)
                    }
                }
            }

            if let errorMessage = appModel.errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            }

            Divider().padding(.vertical, 6).padding(.horizontal, 8)

            VStack(spacing: 2) {
                HoverRow(icon: "arrow.clockwise", title: "Refresh Devices", isLoading: appModel.isRefreshingDevices) {
                    Task { await appModel.refreshDevices() }
                }
                .keyboardShortcut("r")

                HoverRow(icon: "plus.circle", title: "Add a Device…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "add-device")
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
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .padding(.vertical, 8)
    }
}
