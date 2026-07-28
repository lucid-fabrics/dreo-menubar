import XCTest
@testable import DreoBar

final class DeviceTemplateCatalogTests: XCTestCase {
    func test_catalog_loadsBundledTemplates() {
        XCTAssertGreaterThan(DeviceTemplateCatalog.modelCount, 50)
    }

    func test_catalog_hasSchemaForModelTheServerDoesNotDescribe() throws {
        // DR-HPF008S is the case that motivated this: the API returns only
        // {"template": "DR-HPF008S"} for it.
        let schema = try XCTUnwrap(DeviceTemplateCatalog.schema(forModel: "DR-HPF008S"))

        let speed = try XCTUnwrap(schema.control.first { $0.type == "Speed" })
        let levels = (speed.items ?? []).compactMap(\.value.intValue)
        XCTAssertEqual(levels.min(), 1)
        XCTAssertEqual(levels.max(), 9)

        let mode = try XCTUnwrap(schema.control.first { $0.type == "Mode" })
        XCTAssertEqual((mode.items ?? []).map(\.text), ["Normal", "Auto", "Sleep", "Natural"])
        XCTAssertEqual((mode.items ?? []).compactMap(\.value.intValue), [1, 4, 3, 2])

        // Panel Sound is reported inverted: muteon == true means sound off.
        let panelSound = try XCTUnwrap(schema.preference.first { $0.cmd == "muteon" })
        XCTAssertEqual(panelSound.reverse, true)
    }

    func test_catalog_returnsNilForUnknownModel() {
        XCTAssertNil(DeviceTemplateCatalog.schema(forModel: "DR-NOT-A-REAL-MODEL"))
    }

    func test_catalog_everyControlSectionHasSelectableItems() throws {
        // A section with no items would render as an empty header, so the
        // generator drops those. Guard against that regressing.
        for model in ["DR-HPF008S", "DR-HTF004S"] {
            let schema = try XCTUnwrap(DeviceTemplateCatalog.schema(forModel: model))
            for section in schema.control {
                XCTAssertFalse(section.items?.isEmpty ?? true, "\(model)/\(section.type) has no items")
            }
        }
    }
}
