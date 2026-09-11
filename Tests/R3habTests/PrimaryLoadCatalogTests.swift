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

    func testChartLoadTitleKeepsSeatedExtensionLabel() {
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.chartLoadTitle, "Seated extension load")
        XCTAssertEqual(PrimaryLoadCatalog.spanishSquat.chartLoadTitle, "Spanish squat load")
        XCTAssertEqual(PrimaryLoadCatalog.wallSit.chartLoadTitle, "Wall sit load")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.chartLoadTitle, "Leg press load")
    }

    func testBrandCopyHasThreeHabits() {
        XCTAssertEqual(BrandCopy.habits.map(\.title), ["Identity", "Process", "Outcome"])
        XCTAssertTrue(BrandCopy.onboardingTitle.contains("3"))
        XCTAssertEqual(BrandCopy.privacyPoints.map(\.title), ["Completely private", "No ads", "On-device only"])
    }

    func testQLOptionsAreHipThrustSideBendAndWalk() {
        let options = PrimaryLoadCatalog.options(for: .ql)
        XCTAssertEqual(options.map(\.id), ["ql-hip-thrust", "ql-side-bend", "ql-walk"])
        XCTAssertEqual(PrimaryLoadCatalog.defaultID(for: .ql), "ql-hip-thrust")
        XCTAssertTrue(PrimaryLoadCatalog.hipThrust.plotsLoad)
        XCTAssertTrue(PrimaryLoadCatalog.standingSideBend.plotsLoad)
        XCTAssertFalse(PrimaryLoadCatalog.walking.plotsLoad)
        XCTAssertEqual(PrimaryLoadCatalog.walking.chartLoadTitle, "Walking")
        XCTAssertTrue(PrimaryLoadCatalog.contains("ql-hip-thrust", on: .ql))
        XCTAssertFalse(PrimaryLoadCatalog.contains("seated-extension", on: .ql))
    }

    func testTrackMismatchFallsBackToTrackDefault() {
        XCTAssertEqual(
            PrimaryLoadCatalog.normalizedID("seated-extension", track: .ql),
            PrimaryLoadCatalog.hipThrust.id
        )
        XCTAssertEqual(
            PrimaryLoadCatalog.normalizedID("ql-hip-thrust", track: .knee),
            PrimaryLoadCatalog.seatedExtension.id
        )
    }

    func testQLPresetsMapAndWalkingIsNotHard() {
        let hip = SessionPreset.preferred(for: .bIsometrics, primaryLoadID: PrimaryLoadCatalog.hipThrust.id)
        XCTAssertEqual(hip.id, "ql-ht")
        XCTAssertEqual(hip.sessionType, .hsrStrength)
        XCTAssertEqual(hip.loadRegion, .ql)
        XCTAssertTrue(SessionSpacing.isHard(hip.sessionType))

        let side = SessionPreset.preferred(for: .cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.standingSideBend.id)
        XCTAssertEqual(side.id, "ql-sb")
        XCTAssertTrue(SessionSpacing.isHard(side.sessionType))

        let walk = SessionPreset.preferred(for: .bIsometrics, primaryLoadID: PrimaryLoadCatalog.walking.id)
        XCTAssertEqual(walk.id, "ql-walk")
        XCTAssertEqual(walk.sessionType, .other)
        XCTAssertFalse(walk.tracksResistance)
        XCTAssertFalse(SessionSpacing.isHard(walk.sessionType))
    }

    func testQLPhaseChipsStayOnQLTrack() {
        let chips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.hipThrust.id)
        XCTAssertEqual(chips.first?.id, "ql-ht")
        XCTAssertTrue(chips.allSatisfy { $0.tracks.contains(.ql) })
        XCTAssertFalse(chips.contains { $0.id == "ext" })
        XCTAssertTrue(chips.contains { $0.id == "ql-walk" })
    }

    func testKneePhaseChipsStayOnKneeTrack() {
        let chips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(chips.first?.id, "ext")
        XCTAssertTrue(chips.allSatisfy { $0.tracks.contains(.knee) })
        XCTAssertFalse(chips.contains { $0.id == "ql-ht" })
    }
}
