import XCTest
@testable import R3hab

final class PrimaryLoadCatalogTests: XCTestCase {
    func testDefaultIsSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.defaultID, "seated-extension")
        XCTAssertEqual(PrimaryLoadCatalog.defaultSelectable.title, "Seated extension")
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "seated-extension").isometricPresetID, "ext")
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "seated-extension").hsrPresetID, "ke")
        XCTAssertFalse(PrimaryLoadCatalog.defaultSelectable.title.contains("HSR"))
    }

    func testKneeOptionsAreOnlySeatedExtensionAndLegPress() {
        let options = PrimaryLoadCatalog.options(for: .knee)
        XCTAssertEqual(options.map(\.id), ["seated-extension", "leg-press"])
        XCTAssertEqual(options.map(\.title), ["Seated extension", "Leg press"])
        XCTAssertFalse(options.contains { $0.title.contains("HSR") })
        XCTAssertFalse(PrimaryLoadCatalog.contains("spanish-squat", on: .knee))
        XCTAssertFalse(PrimaryLoadCatalog.contains("wall-sit", on: .knee))
    }

    func testRetiredKneePrimariesRemapToSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("spanish-squat"), PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("wall-sit"), PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "spanish-squat").id, PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "wall-sit").id, PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertTrue(PrimaryLoadCatalog.needsRemap("spanish-squat", track: .knee))
        XCTAssertTrue(PrimaryLoadCatalog.needsRemap("wall-sit", track: .knee))
        XCTAssertFalse(PrimaryLoadCatalog.needsRemap("seated-extension", track: .knee))
        XCTAssertFalse(PrimaryLoadCatalog.needsRemap("leg-press", track: .knee))
    }

    func testUnknownIdFallsBackToSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("not-a-lift"), PrimaryLoadCatalog.defaultID)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "").id, PrimaryLoadCatalog.defaultID)
    }

    func testPhaseBPrefersIsometricVariant() {
        let seated = SessionPreset.preferred(for: .bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(seated.id, "ext")
        XCTAssertEqual(seated.label, "Seated extension")
        XCTAssertTrue(seated.tracksResistance)
        XCTAssertTrue(seated.usesIsoHoldLogging)

        let press = SessionPreset.preferred(for: .aFlareDeLoad, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(press.id, "lp-iso")
        XCTAssertEqual(press.label, "Leg press")
        XCTAssertTrue(press.tracksResistance)
        XCTAssertTrue(press.usesPerSetLogging)
        XCTAssertTrue(press.usesIsoHoldLogging)
        XCTAssertNotEqual(press.id, "ext")
    }

    func testPhaseCPrefersHSRVariant() {
        let seated = SessionPreset.preferred(for: .cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(seated.id, "ke")
        XCTAssertEqual(seated.label, "Seated extension")
        XCTAssertFalse(seated.label.contains("HSR"))
        XCTAssertTrue(seated.tracksResistance)
        XCTAssertTrue(seated.usesPerSetLogging)

        let press = SessionPreset.preferred(for: .cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(press.id, "lp")
        XCTAssertEqual(press.label, "Leg press")
        XCTAssertFalse(press.label.contains("HSR"))
        XCTAssertTrue(press.tracksResistance)
        XCTAssertTrue(press.usesPerSetLogging)
        XCTAssertFalse(press.usesIsoHoldLogging)
    }

    func testForPhaseSortsPreferredFirst() {
        let chips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(chips.first?.id, "lp-iso")
    }

    func testKneePhaseChipsOmitRetiredLiftsAndKeepBothLoaders() {
        let isoChips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(isoChips.first?.id, "ext")
        XCTAssertTrue(isoChips.contains { $0.id == "lp-iso" })
        XCTAssertFalse(isoChips.contains { $0.id == "wall" })
        XCTAssertFalse(isoChips.contains { $0.id == "spanish" })
        XCTAssertFalse(isoChips.contains { $0.label.contains("HSR") })

        let hsrChips = SessionPreset.forPhase(.cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(hsrChips.first?.id, "lp")
        XCTAssertTrue(hsrChips.contains { $0.id == "ke" })
        XCTAssertFalse(hsrChips.contains { $0.id == "spanish" })
        XCTAssertTrue(hsrChips.allSatisfy { !$0.label.contains("HSR") })
    }

    func testKneeChipsAreSeatedExtensionAndLegPressOnly() {
        // Adi (PR #18): no "Easy bike", no "Custom…" in the knee chip row.
        XCTAssertFalse(SessionPreset.all.contains { $0.id == "bike" || $0.id == "custom" })
        XCTAssertFalse(SessionPreset.all.contains { $0.label == "Easy bike" || $0.label.hasPrefix("Custom") })

        let phaseB = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(phaseB.map(\.id), ["ext", "lp-iso"])
        XCTAssertEqual(phaseB.map(\.label), ["Seated extension", "Leg press"])

        let phaseA = SessionPreset.forPhase(.aFlareDeLoad, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(phaseA.map(\.id), ["lp-iso", "ext"])

        let phaseC = SessionPreset.forPhase(.cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(phaseC.map(\.id), ["ke", "lp"])
    }

    func testKneeLoadersStayAvailableInLaterPhases() {
        // With bike/custom gone, D/E rows still lead with the primary lift.
        let phaseD = SessionPreset.forPhase(.dEnergyStorage, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(phaseD.first?.id, "ke")
        XCTAssertTrue(phaseD.contains { $0.id == "lp" })
        XCTAssertTrue(phaseD.contains { $0.id == "land" })

        let phaseE = SessionPreset.forPhase(.eReturnToSport, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(phaseE.first?.id, "lp")
        XCTAssertTrue(phaseE.contains { $0.id == "ke" })
        XCTAssertFalse(phaseE.contains { $0.id == "bike" || $0.id == "custom" })
    }

    func testQLChipsDoNotIncludeBikeOrCustom() {
        for phase in RehabPhase.allCases {
            let chips = SessionPreset.forPhase(phase, primaryLoadID: PrimaryLoadCatalog.hipThrust.id)
            XCTAssertEqual(chips.map(\.id), ["ql-ht", "ql-sb", "ql-walk"], "\(phase)")
        }
    }

    func testChartLoadTitleKeepsSeatedExtensionLabel() {
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.chartLoadTitle, "Seated extension load")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.chartLoadTitle, "Leg press load")
    }

    func testBrandCopyHasJourneyCardsNotNameStory() {
        XCTAssertEqual(
            BrandCopy.habits.map(\.title),
            ["Track the journey", "Stay accountable", "Trust the data"]
        )
        XCTAssertEqual(BrandCopy.onboardingEyebrow, "Welcome")
        XCTAssertEqual(BrandCopy.onboardingTitle, "Your personal rehab assistant.")
        XCTAssertFalse(BrandCopy.onboardingTitle.contains("3"))
        XCTAssertFalse(BrandCopy.settingsBlurb.contains("Identity"))
        XCTAssertFalse(BrandCopy.settingsBlurb.contains("Process"))
        XCTAssertFalse(BrandCopy.settingsBlurb.contains("written with a 3"))
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
