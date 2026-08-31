import XCTest
@testable import R3hab

final class PrimaryLoadCatalogTests: XCTestCase {
    func testDefaultIsSeatedLegExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.defaultID, "seated-extension")
        XCTAssertEqual(PrimaryLoadCatalog.defaultSelectable.title, "Seated leg extension")
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "seated-extension").isometricPresetID, "ext")
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "seated-extension").hsrPresetID, "ke")
    }

    func testUnknownIdFallsBackToSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("not-a-lift"), PrimaryLoadCatalog.defaultID)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "").id, PrimaryLoadCatalog.defaultID)
    }

    func testPhaseBPrefersIsometricVariant() {
        let seated = SessionPreset.preferred(for: .bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(seated.id, "ext")

        let wall = SessionPreset.preferred(for: .aFlareDeLoad, primaryLoadID: PrimaryLoadCatalog.wallSit.id)
        XCTAssertEqual(wall.id, "wall")

        let spanish = SessionPreset.preferred(for: .bIsometrics, primaryLoadID: PrimaryLoadCatalog.spanishSquat.id)
        XCTAssertEqual(spanish.id, "spanish")
    }

    func testPhaseCPrefersHSRVariant() {
        let seated = SessionPreset.preferred(for: .cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(seated.id, "ke")

        let press = SessionPreset.preferred(for: .cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(press.id, "lp")

        let wallHSR = SessionPreset.preferred(for: .cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.wallSit.id)
        XCTAssertEqual(wallHSR.id, "ke")
    }

    func testForPhaseSortsPreferredFirst() {
        let chips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.wallSit.id)
        XCTAssertEqual(chips.first?.id, "wall")
    }

    func testBrandCopyHasThreeHabits() {
        XCTAssertEqual(BrandCopy.habits.map(\.title), ["Record", "Reload", "Resolve"])
        XCTAssertTrue(BrandCopy.onboardingTitle.contains("3"))
    }
}
