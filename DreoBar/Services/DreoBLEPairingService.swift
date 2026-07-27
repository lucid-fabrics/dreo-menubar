import CoreBluetooth
import Foundation
import os

/// Pairs a new fan onto WiFi over Bluetooth LE, reimplementing the "HeFi"
/// protocol confirmed by live Frida capture of a real pairing session
/// against the official Dreo Android app (2026-07-27): see `DreoBLE`,
/// `DreoBLEMessage`, `DiscoveredWiFiNetwork`.
///
/// CoreBluetooth's delegate protocols aren't `Sendable`-annotated and their
/// callbacks are inherently nonisolated by contract, which doesn't fit
/// Swift 6 actor isolation cleanly (Apple hasn't marked CB types Sendable
/// yet). This class sidesteps that friction the standard way: it isn't
/// actor-isolated at all, `queue: .main` on the central manager guarantees
/// every delegate callback and every call we make into CoreBluetooth
/// happens serially on the main thread, so `nonisolated(unsafe)` on the
/// mutable state is an accurate description of the actual guarantee, not
/// a workaround around it.
final class DreoBLEPairingService: NSObject, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.dreobar", category: "DreoBLEPairingService")

    private lazy var centralManager = CBCentralManager(delegate: self, queue: .main)
    private nonisolated(unsafe) var peripheral: CBPeripheral?
    private nonisolated(unsafe) var characteristics: [CBUUID: CBCharacteristic] = [:]

    private nonisolated(unsafe) var poweredOnContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var discoveryContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var connectContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var servicesContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var notifyStateContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var writeContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var connectResultContinuation: CheckedContinuation<Void, Error>?

    /// Set only while `scanWiFiNetworks(timeout:)` is collecting; every
    /// `"wl"` notification during that window feeds networks through here.
    private nonisolated(unsafe) var wifiScanHandler: ((DiscoveredWiFiNetwork) -> Void)?

    /// Case-insensitive name prefix used to pick the right peripheral out
    /// of a scan; the fan's pairing-mode WiFi SoftAP uses the same "DREO"
    /// prefix, so the BLE advertisement is expected to match.
    private nonisolated(unsafe) var namePrefix = "DREO"

    func connectToFan(namePrefix: String = "DREO", timeout: Duration = .seconds(20)) async throws {
        self.namePrefix = namePrefix
        try await waitUntilPoweredOn()
        try await discoverPeripheral(timeout: timeout)
        guard let found = peripheral else { throw DreoBLEError.peripheralNotFound }
        found.delegate = self
        try await connect(found)
        try await discoverServicesAndCharacteristics(found)
        try await subscribeToNotifications()
        try await send(DreoBLEMessage.setTime())
        // The fan rejects a later `cw` (join WiFi) unless the session was
        // opened the way the official app opens it. Verified live on
        // 2026-07-27: st -> rd -> pd -> rw -> cw succeeds, while
        // st -> rw -> cw is refused with an `ee` error.
        try await send(DreoBLEMessage.readDeviceInfo())
    }

    /// Best-effort: tells the fan which account to bind to once it's
    /// online. Only sent when the caller has a verified numeric account
    /// id, a wrong value would bind the device to the wrong account, so
    /// skipping this is safer than guessing.
    func provisionAccount(userId: UInt64, deviceAPIHost: String) async throws {
        try await send(DreoBLEMessage.provisionDomains(userId: userId, deviceAPIHost: deviceAPIHost))
    }

    /// Asks the fan to report its identity, matching the official app's
    /// order (`st` then `rd` before anything else). The reply arrives as
    /// an `ri` notification.
    func readDeviceInfo() async throws {
        try await send(DreoBLEMessage.readDeviceInfo())
    }

    /// Negotiated ATT MTU, or nil when not connected. CoreBluetooth gives
    /// no way to *request* an MTU, so this is read-only: it decides whether
    /// a message fits in one write or gets split into prepare/execute
    /// writes, which this peripheral may reject.
    var negotiatedMTU: Int? {
        peripheral.map { $0.maximumWriteValueLength(for: .withoutResponse) + 3 }
    }

    /// Largest payload that still fits in a single ATT write.
    var singleWriteLimit: Int? {
        peripheral.map { $0.maximumWriteValueLength(for: .withoutResponse) }
    }

    func disconnect() {
        if let peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        centralManager.stopScan()
        peripheral = nil
        characteristics = [:]
        failAllPendingContinuations()
    }

    private func failAllPendingContinuations() {
        poweredOnContinuation?.resume(throwing: CancellationError())
        poweredOnContinuation = nil
        discoveryContinuation?.resume(throwing: CancellationError())
        discoveryContinuation = nil
        connectContinuation?.resume(throwing: CancellationError())
        connectContinuation = nil
        servicesContinuation?.resume(throwing: CancellationError())
        servicesContinuation = nil
        notifyStateContinuation?.resume(throwing: CancellationError())
        notifyStateContinuation = nil
        writeContinuation?.resume(throwing: CancellationError())
        writeContinuation = nil
        connectResultContinuation?.resume(throwing: CancellationError())
        connectResultContinuation = nil
        wifiScanHandler = nil
    }

    func scanWiFiNetworks(timeout: Duration = .seconds(8)) async throws -> [DiscoveredWiFiNetwork] {
        var seen: [String: DiscoveredWiFiNetwork] = [:]
        wifiScanHandler = { seen[$0.ssid] = $0 }
        defer { wifiScanHandler = nil }

        try await send(DreoBLEMessage.requestWiFiScan())
        try? await Task.sleep(for: timeout)

        return seen.values.sorted { $0.rssi > $1.rssi }
    }

    func sendCredentials(
        network: DiscoveredWiFiNetwork,
        password: String,
        includeSelfCheck: Bool = true,
        timeout: Duration = .seconds(45)
    ) async throws {
        let payload = DreoBLEMessage.connectWiFi(
            network: network,
            password: password,
            includeSelfCheck: includeSelfCheck
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectResultContinuation = continuation
            Task {
                do {
                    try await send(payload)
                } catch {
                    guard let pending = connectResultContinuation else { return }
                    connectResultContinuation = nil
                    pending.resume(throwing: error)
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                guard let pending = connectResultContinuation else { return }
                connectResultContinuation = nil
                pending.resume(throwing: DreoBLEError.joinTimedOut)
            }
        }
    }

    // MARK: - Connection setup internals

    private func waitUntilPoweredOn() async throws {
        if centralManager.state == .poweredOn { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            poweredOnContinuation = continuation
        }
    }

    private func discoverPeripheral(timeout: Duration) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoveryContinuation = continuation
            centralManager.scanForPeripherals(withServices: nil)
            Task {
                try? await Task.sleep(for: timeout)
                guard let pending = discoveryContinuation else { return }
                discoveryContinuation = nil
                centralManager.stopScan()
                pending.resume(throwing: DreoBLEError.peripheralNotFound)
            }
        }
    }

    private func connect(_ peripheral: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectContinuation = continuation
            centralManager.connect(peripheral)
        }
    }

    private func discoverServicesAndCharacteristics(_ peripheral: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            servicesContinuation = continuation
            peripheral.discoverServices(nil)
        }
        guard characteristics[DreoBLE.writeCharacteristic] != nil,
              characteristics[DreoBLE.notifyCharacteristic] != nil else {
            throw DreoBLEError.characteristicNotFound
        }
    }

    private func subscribeToNotifications() async throws {
        guard let peripheral, let characteristic = characteristics[DreoBLE.notifyCharacteristic] else {
            throw DreoBLEError.characteristicNotFound
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notifyStateContinuation = continuation
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    private func send(_ payload: Data) async throws {
        guard let peripheral, let characteristic = characteristics[DreoBLE.writeCharacteristic] else {
            throw DreoBLEError.characteristicNotFound
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writeContinuation = continuation
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension DreoBLEPairingService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Self.logger.debug("Central state: \(String(describing: central.state), privacy: .public)")
        if central.state == .poweredOn, let continuation = poweredOnContinuation {
            poweredOnContinuation = nil
            continuation.resume()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        Self.logger.debug("Discovered: '\(name, privacy: .public)' rssi=\(RSSI, privacy: .public)")
        guard name.uppercased().hasPrefix(namePrefix.uppercased()) else { return }
        guard let continuation = discoveryContinuation else {
            Self.logger.debug("Matched '\(name, privacy: .public)' but no pending discovery continuation")
            return
        }
        Self.logger.debug("Matched '\(name, privacy: .public)', stopping scan and connecting")
        discoveryContinuation = nil
        centralManager.stopScan()
        self.peripheral = peripheral
        continuation.resume()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Self.logger.debug("Connected to peripheral")
        guard let continuation = connectContinuation else {
            Self.logger.debug("didConnect fired but no pending connect continuation")
            return
        }
        connectContinuation = nil
        continuation.resume()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Self.logger.debug("Failed to connect: \(String(describing: error), privacy: .public)")
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        continuation.resume(throwing: error ?? DreoBLEError.notConnected)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Self.logger.info("Peripheral disconnected: \(String(describing: error), privacy: .public)")
    }
}

// MARK: - CBPeripheralDelegate

extension DreoBLEPairingService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let uuids = peripheral.services?.map { $0.uuid.uuidString } ?? []
        let errorDescription = String(describing: error)
        Self.logger.debug("Services discovered: \(uuids, privacy: .public) error=\(errorDescription, privacy: .public)")
        guard let service = peripheral.services?.first(where: { $0.uuid == DreoBLE.service }) else {
            servicesContinuation?.resume(throwing: DreoBLEError.serviceNotFound)
            servicesContinuation = nil
            return
        }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let uuids = service.characteristics?.map { $0.uuid.uuidString } ?? []
        Self.logger.debug("Characteristics for \(service.uuid, privacy: .public): \(uuids, privacy: .public)")
        guard let continuation = servicesContinuation else { return }
        servicesContinuation = nil

        if let error {
            continuation.resume(throwing: error)
            return
        }
        for characteristic in service.characteristics ?? [] {
            characteristics[characteristic.uuid] = characteristic
        }
        continuation.resume()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let continuation = notifyStateContinuation else { return }
        notifyStateContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let continuation = writeContinuation else { return }
        writeContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == DreoBLE.notifyCharacteristic, error == nil, let data = characteristic.value else {
            return
        }
        Self.logger.debug("Notification: \(data.map { String(format: "%02x", $0) }.joined(), privacy: .public)")
        guard let notification = DreoBLENotification(data: data) else { return }

        switch notification {
        case .wifiNetworks(let networks):
            networks.forEach { wifiScanHandler?($0) }
        case .connectFinished(let success):
            guard let continuation = connectResultContinuation else { return }
            connectResultContinuation = nil
            if success {
                continuation.resume()
            } else {
                continuation.resume(throwing: DreoBLEError.joinRejected)
            }
        case .error(let code):
            guard let continuation = connectResultContinuation else { return }
            connectResultContinuation = nil
            continuation.resume(throwing: DreoBLEError.deviceRejected(code: code))
        case .other:
            break
        }
    }
}
