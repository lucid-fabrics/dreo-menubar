import XCTest
@testable import Windbar

final class DeviceAvailabilityTests: XCTestCase {
    private func device(
        serialNumber: String = "SN1",
        state: [String: DreoValue]
    ) -> DreoDevice {
        DreoDevice(
            serialNumber: serialNumber,
            deviceName: "Fan",
            model: "DR-HTF004S",
            controlsConf: nil,
            state: state
        )
    }

    func test_isOnline_followsConnectedFlag() {
        XCTAssertTrue(device(state: ["connected": .bool(true)]).isOnline)
        XCTAssertFalse(device(state: ["connected": .bool(false)]).isOnline)
    }

    func test_isOnline_defaultsToTrueWhenDeviceNeverReportsIt() {
        // Staying quiet must not be mistaken for being unreachable.
        XCTAssertTrue(device(state: ["poweron": .bool(true)]).isOnline)
    }

    @MainActor
    private func readyModel(with devices: [DreoDevice]) async -> AppModel {
        let apiStub = DreoAPIServiceStub()
        await apiStub.setDevicesResult(.success(devices))
        await apiStub.setSession(DreoSession(accessToken: "tok", regionHost: "us"))
        let model = AppModel(
            apiService: apiStub,
            socketService: DreoSocketServiceFake(),
            keychainRepository: KeychainRepositoryFake(
                stored: DreoCredentials(email: "user@example.com", password: "secret")
            ),
            settingsRepository: SettingsRepositoryFake()
        )
        await model.start()
        return model
    }

    @MainActor
    func test_menuBarSymbol_showsOfflineRatherThanStaleRunningState() async {
        // The device still reports poweron == true, but it can't be reached,
        // so the icon must not claim it is running.
        let model = await readyModel(with: [
            device(state: ["poweron": .bool(true), "connected": .bool(false)])
        ])

        XCTAssertEqual(model.menuBarSymbol, "fan.slash")
    }

    @MainActor
    func test_hotkeyTargetSkipsOfflineDeviceWhenNothingWasChosen() async {
        let model = await readyModel(with: [
            device(serialNumber: "OFF", state: ["connected": .bool(false)]),
            device(serialNumber: "ON", state: ["connected": .bool(true)])
        ])

        XCTAssertEqual(model.lastSelectedOrFirstDevice?.serialNumber, "ON")
    }
}
