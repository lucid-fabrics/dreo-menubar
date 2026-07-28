import XCTest
@testable import DreoBar

final class DeviceLabelsTests: XCTestCase {
    func test_table_loadsFromBundle() {
        XCTAssertGreaterThan(DeviceLabels.count, 200)
    }

    func test_keysWithoutWordSeparatorsResolveProperly() {
        // Splitting on underscores turns these into "Panelsound" and
        // "Lightdetection", which is what the UI used to show.
        XCTAssertEqual("device_control_panelsound".dreoTitleCased, "Panel Sound")
        XCTAssertEqual("device_control_lightdetection".dreoTitleCased, "Adaptive Display")
    }

    func test_labelsMatchTheWordingTheDreoAppUses() {
        // Tidying the key alone yields "Straight"; the product calls it Normal.
        XCTAssertEqual("device_fans_mode_straight".dreoTitleCased, "Normal")
        XCTAssertEqual("device_control_childlock".dreoTitleCased, "Child Lock")
    }

    func test_alreadyEnglishTextIsLeftAlone() {
        // The bundled templates ship resolved English, which must survive.
        XCTAssertEqual("Panel Sound".dreoTitleCased, "Panel Sound")
        XCTAssertEqual("30°".dreoTitleCased, "30°")
    }

    func test_unknownKeyFallsBackToTidyingIt() {
        XCTAssertEqual("device_control_madeup_thing".dreoTitleCased, "Madeup Thing")
    }
}
