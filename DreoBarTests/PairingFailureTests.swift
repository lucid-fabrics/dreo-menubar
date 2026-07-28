import XCTest
@testable import DreoBar

final class PairingFailureTests: XCTestCase {
    func test_bluetoothOff_offersSettingsRatherThanRetry() {
        let failure = PairingFailure(DreoBLEError.bluetoothUnavailable(.poweredOff))

        // Retrying cannot help while the radio is off, so the only useful
        // action is the one that turns it on.
        guard case .openSettings(let url, _) = failure.recovery else {
            return XCTFail("expected .openSettings, got \(failure.recovery)")
        }
        XCTAssertTrue(url.contains("BluetoothSettings"))
    }

    func test_unsupportedHardware_offersNoRecovery() {
        let failure = PairingFailure(DreoBLEError.bluetoothUnavailable(.unsupported))
        XCTAssertEqual(failure.recovery, .none)
    }

    func test_rejectedCredentials_sendsUserBackToNetworkChoice() {
        XCTAssertEqual(PairingFailure(DreoBLEError.joinRejected).recovery, .chooseNetworkAgain)
        XCTAssertEqual(
            PairingFailure(DreoBLEError.deviceRejected(code: Data([3, 2, 0, 1]))).recovery,
            .chooseNetworkAgain
        )
    }

    func test_noFanFound_isRetryable() {
        XCTAssertEqual(PairingFailure(DreoBLEError.peripheralNotFound).recovery, .retry)
        XCTAssertEqual(PairingFailure(DreoBLEError.joinTimedOut).recovery, .retry)
    }

    func test_unknownError_stillProducesActionableGuidance() {
        struct Surprise: Error {}
        let failure = PairingFailure(Surprise())

        XCTAssertEqual(failure.recovery, .retry)
        XCTAssertFalse(failure.title.isEmpty)
        XCTAssertFalse(failure.detail.isEmpty)
        // Raw error text must never reach the user.
        XCTAssertFalse(failure.detail.contains("Surprise"))
    }
}
