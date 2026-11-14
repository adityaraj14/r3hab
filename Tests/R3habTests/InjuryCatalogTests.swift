import XCTest
@testable import R3hab

final class InjuryCatalogTests: XCTestCase {
    func testCatalogShipsKneeAndQL() {
        XCTAssertEqual(InjuryCatalog.all.map(\.id), ["patellar-tendinopathy", "ql-strain"])
        XCTAssertEqual(
            InjuryCatalog.defaultSelectable.title,
            "Patellar tendinopathy, or jumper's knee, or patellar tendonitis"
        )
        XCTAssertTrue(InjuryCatalog.contains("patellar-tendinopathy"))
        XCTAssertTrue(InjuryCatalog.contains("ql-strain"))
        XCTAssertEqual(InjuryCatalog.qlStrain.protocolName, "QL strain")
        XCTAssertNotEqual(InjuryCatalog.qlStrain.protocolName, InjuryCatalog.patellarTendinopathy.protocolName)
    }

    func testKneeAliasesRemapToPatellarTendinopathy() {
        XCTAssertEqual(InjuryCatalog.normalizedID("jumpers-knee"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.normalizedID("patellar-tendonitis"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.definition(for: "jumpers-knee").id, "patellar-tendinopathy")
        XCTAssertTrue(InjuryCatalog.needsRemap("jumpers-knee"))
        XCTAssertTrue(InjuryCatalog.needsRemap("patellar-tendonitis"))
        XCTAssertFalse(InjuryCatalog.needsRemap("patellar-tendinopathy"))
    }

    func testQLStrainStaysSelectable() {
        XCTAssertFalse(InjuryCatalog.retiredIDs.contains("ql-strain"))
        XCTAssertFalse(InjuryCatalog.needsRemap("ql-strain"))
        XCTAssertEqual(InjuryCatalog.normalizedID("ql-strain"), "ql-strain")
        XCTAssertEqual(InjuryCatalog.definition(for: "ql-strain").id, InjuryCatalog.qlStrain.id)
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapInjury("ql-strain"))
    }

    func testUnknownIdFallsBackToPatellarTendinopathy() {
        let fallback = InjuryCatalog.definition(for: "future-achilles")
        XCTAssertEqual(fallback.id, InjuryCatalog.defaultSelectable.id)
        XCTAssertEqual(InjuryCatalog.normalizedID("not-a-real-injury"), "patellar-tendinopathy")
        XCTAssertFalse(InjuryCatalog.contains("future-achilles"))
    }

}
