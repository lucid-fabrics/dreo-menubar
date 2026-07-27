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
        } label: {
            Image(systemName: appModel.lastSelectedOrFirstDevice?.isOn == true ? "fan.fill" : "fan")
        }
        .menuBarExtraStyle(.window)

        Window("Add a Device", id: "add-device") {
            AddDeviceView()
                .environment(appModel)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
