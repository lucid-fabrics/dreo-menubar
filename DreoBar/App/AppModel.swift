import Foundation
import Observation
import os

@MainActor
@Observable
final class AppModel {
    enum LaunchState: Equatable {
        case loading
        case needsLogin
        case ready
    }

    private(set) var launchState: LaunchState = .loading
    private(set) var devices: [DreoDevice] = []
    private(set) var isRefreshingDevices = false

    /// Set only when the user picks "Add a Device". macOS opens an app's
    /// window scene simply because the app was activated, so the pairing
    /// wizard needs a way to tell a real request from that.
    var hasRequestedPairing = false
    var errorMessage: String?

    var settings: AppSettings = .default {
        didSet {
            guard hasLoadedSettings else { return }
            scheduleSettingsSave()
        }
    }

    @ObservationIgnored private static let logger = Logger(subsystem: "com.dreobar", category: "AppModel")

    @ObservationIgnored private let apiService: DreoAPIServiceProtocol
    @ObservationIgnored private let socketService: DreoSocketServiceProtocol
    @ObservationIgnored private let keychainRepository: KeychainRepositoryProtocol
    @ObservationIgnored private let settingsRepository: SettingsRepositoryProtocol

    @ObservationIgnored private let shortcutBinder = DeviceShortcutBinder()
    @ObservationIgnored private var hasLoadedSettings = false
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(
        apiService: DreoAPIServiceProtocol = DreoAPIService(),
        socketService: DreoSocketServiceProtocol = DreoSocketService(),
        keychainRepository: KeychainRepositoryProtocol = KeychainRepository(),
        settingsRepository: SettingsRepositoryProtocol = SettingsRepository()
    ) {
        self.apiService = apiService
        self.socketService = socketService
        self.keychainRepository = keychainRepository
        self.settingsRepository = settingsRepository
    }

    /// Target for the global hotkey and the URL scheme. An explicit choice
    /// is honoured even while it's offline, but the automatic fallback skips
    /// unreachable devices so the hotkey acts on one that can respond.
    var lastSelectedOrFirstDevice: DreoDevice? {
        if let serialNumber = settings.lastSelectedDeviceSerialNumber,
           let match = devices.first(where: { $0.serialNumber == serialNumber }) {
            return match
        }
        return devices.first(where: \.isOnline) ?? devices.first
    }

    /// Menu bar icon. Only shows running when a device is genuinely both
    /// reachable and on, so a stale "on" from an offline fan doesn't read as
    /// though it's still blowing.
    var menuBarSymbol: String {
        guard let device = lastSelectedOrFirstDevice else { return "fan" }
        guard device.isOnline else { return "fan.slash" }
        return device.isOn ? "fan.fill" : "fan"
    }

    func start() async {
        settings = await settingsRepository.load()
        hasLoadedSettings = true

        guard let credentials = try? await keychainRepository.loadCredentials() else {
            launchState = .needsLogin
            return
        }
        await login(credentials: credentials, persist: false)
    }

    func login(email: String, password: String) async {
        await login(credentials: DreoCredentials(email: email, password: password), persist: true)
    }

    func setValue(_ value: DreoValue, forKey key: String, on device: DreoDevice) {
        guard let index = devices.firstIndex(where: { $0.serialNumber == device.serialNumber }) else { return }
        devices[index].state[key] = value
        settings.lastSelectedDeviceSerialNumber = device.serialNumber

        let serialNumber = device.serialNumber
        Task {
            do {
                try await socketService.sendCommand(serialNumber: serialNumber, key: key, value: value)
            } catch {
                Self.logger.warning("Command failed: \(String(describing: error), privacy: .public)")
                errorMessage = "Couldn't reach \(device.deviceName). Check your connection and try again."
            }
        }
    }

    /// Current login session, including the numeric account id BLE pairing
    /// needs to bind a new fan to this account.
    func currentSession() async -> DreoSession? {
        await apiService.currentSession()
    }

    /// Unbinds a device from the Dreo account. This affects the account, not
    /// just this app, so callers must confirm with the user first.
    func removeDevice(_ device: DreoDevice) async {
        do {
            try await apiService.removeDevice(serialNumber: device.serialNumber)
            devices.removeAll { $0.serialNumber == device.serialNumber }
            if settings.lastSelectedDeviceSerialNumber == device.serialNumber {
                settings.lastSelectedDeviceSerialNumber = nil
            }
        } catch {
            Self.logger.warning("Remove failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't remove \(device.deviceName). Check your connection and try again."
        }
    }

    func togglePower(for device: DreoDevice) {
        setValue(.bool(!device.isOn), forKey: device.powerKey, on: device)
    }

    func toggleLastSelectedDevicePower() {
        guard let device = lastSelectedOrFirstDevice else { return }
        togglePower(for: device)
    }

    /// Toggles one specific device, used by that device's own keyboard
    /// shortcut. Silently does nothing if the device is gone or unreachable,
    /// since a keypress has nowhere to report an error.
    func togglePower(serialNumber: String) {
        guard let device = devices.first(where: { $0.serialNumber == serialNumber }),
              device.isOnline else { return }
        togglePower(for: device)
    }

    /// Re-lists devices on the account. Picks up anything newly paired,
    /// whether through this app's own BLE provisioning or the official
    /// Dreo app.
    func refreshDevices() async {
        guard !isRefreshingDevices else { return }
        isRefreshingDevices = true
        defer { isRefreshingDevices = false }

        do {
            try await loadDevices()
        } catch {
            Self.logger.warning("Refresh failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't refresh devices. Check your connection and try again."
        }
    }

    // MARK: - Login internals

    private func login(credentials: DreoCredentials, persist: Bool) async {
        errorMessage = nil
        do {
            try await apiService.login(credentials)
            if persist {
                try? await keychainRepository.save(credentials)
            }
            try await loadDevicesAndConnect()
            launchState = .ready
        } catch {
            Self.logger.warning("Login failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't sign in. Check your email and password."
            launchState = .needsLogin
        }
    }

    private func loadDevicesAndConnect() async throws {
        try await loadDevices()

        if let session = await apiService.currentSession() {
            await socketService.connect(session: session)
            subscribeToUpdates()
        }
    }

    private func loadDevices() async throws {
        var loaded = try await apiService.listDevices()
        for index in loaded.indices {
            if let state = try? await apiService.fetchState(for: loaded[index].serialNumber) {
                loaded[index].apply(state)
            }
        }
        devices = loaded
        // Bind a shortcut for anything newly seen. Devices only exist after
        // the account loads, so this cannot be declared up front.
        shortcutBinder.bind(devices: loaded) { [weak self] serialNumber in
            self?.togglePower(serialNumber: serialNumber)
        }
    }

    private func subscribeToUpdates() {
        updatesTask?.cancel()
        updatesTask = Task {
            let stream = await socketService.observeUpdates()
            for await update in stream {
                apply(update)
            }
        }
    }

    private func apply(_ update: DreoStateUpdate) {
        guard let index = devices.firstIndex(where: { $0.serialNumber == update.serialNumber }) else { return }
        devices[index].apply(update.changes)
    }

    private func scheduleSettingsSave() {
        settingsSaveTask?.cancel()
        let current = settings
        settingsSaveTask = Task { try? await settingsRepository.save(current) }
    }
}
