import SwiftUI

@main
struct DreoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let model = AppModel()
        _appModel = State(initialValue: model)
        appDelegate.configure(appModel: model)
        Task { await model.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appModel: appModel)
                .tint(Theme.accent)
        } label: {
            Image(systemName: appModel.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Add a Device", id: "add-device") {
            AddDeviceView(appModel: appModel)
                .tint(Theme.accent)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(appModel: appModel)
                .tint(Theme.accent)
        }
    }

}
