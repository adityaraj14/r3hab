import XCTest
@testable import R3hab

final class PrimaryLoadCatalogTests: XCTestCase {
    func testDefaultIsSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.defaultID, "seated-extension")
        XCTAssertEqual(PrimaryLoadCatalog.defaultSelectable.title, "Seated leg extension")
        XCTAssertEqual(PrimaryLoadCatalog.defaultSelectable.logCTA, "Log Workout")
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "seated-extension").isometricPresetID, "ext")
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "seated-extension").hsrPresetID, "ke")
        XCTAssertFalse(PrimaryLoadCatalog.defaultSelectable.title.contains("HSR"))
    }

    func testCatalogIsOnlySeatedExtensionAndLegPress() {
        let options = PrimaryLoadCatalog.options(for: InjuryCatalog.patellarTendinopathy.id)
        XCTAssertEqual(options.map(\.id), ["seated-extension", "leg-press"])
        XCTAssertEqual(options.map(\.title), ["Seated leg extension", "Leg press"])
        XCTAssertEqual(options.map(\.logCTA), ["Log Workout", "Log leg press"])
        XCTAssertFalse(options.contains { $0.title.contains("HSR") })
        XCTAssertFalse(PrimaryLoadCatalog.contains("spanish-squat"))
        XCTAssertFalse(PrimaryLoadCatalog.contains("wall-sit"))
    }

    func testRetiredKneePrimariesRemapToSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("spanish-squat"), PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("wall-sit"), PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "spanish-squat").id, PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "wall-sit").id, PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertTrue(PrimaryLoadCatalog.needsRemap("spanish-squat"))
        XCTAssertTrue(PrimaryLoadCatalog.needsRemap("wall-sit"))
        XCTAssertFalse(PrimaryLoadCatalog.needsRemap("seated-extension"))
        XCTAssertFalse(PrimaryLoadCatalog.needsRemap("leg-press"))
    }

    func testQLModalitiesStayLiveAndAreScoped() {
        XCTAssertEqual(
            PrimaryLoadCatalog.options(for: InjuryCatalog.qlStrain.id).map(\.id),
            ["ql-walk", "ql-side-bend", "ql-hip-thrust"]
        )
        for live in ["ql-hip-thrust", "ql-side-bend", "ql-walk"] {
            XCTAssertEqual(PrimaryLoadCatalog.normalizedID(live), live, live)
            XCTAssertFalse(PrimaryLoadCatalog.needsRemap(live), live)
            XCTAssertEqual(
                PrimaryLoadCatalog.normalizedID(live, injuryID: InjuryCatalog.qlStrain.id),
                live,
                live
            )
            XCTAssertEqual(
                PrimaryLoadCatalog.normalizedID(live, injuryID: InjuryCatalog.patellarTendinopathy.id),
                PrimaryLoadCatalog.seatedExtension.id,
                live
            )
        }
        XCTAssertEqual(
            PrimaryLoadCatalog.normalizedID("seated-extension", injuryID: InjuryCatalog.qlStrain.id),
            PrimaryLoadCatalog.qlWalk.id
        )
        XCTAssertTrue(SessionPreset.all.contains { $0.id == "ql-walk" })
        let qlChips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.qlWalk.id)
        XCTAssertEqual(qlChips.map(\.id), ["ql-walk", "ql-side-bend", "ql-hip-thrust"])
        let kneeChips = SessionPreset.forPhase(.bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertFalse(kneeChips.contains { $0.id.hasPrefix("ql-") })
    }

    func testUnknownIdFallsBackToSeatedExtension() {
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("not-a-lift"), PrimaryLoadCatalog.defaultID)
        XCTAssertEqual(PrimaryLoadCatalog.option(for: "").id, PrimaryLoadCatalog.defaultID)
    }

    func testPhaseBPrefersIsometricVariant() {
        let seated = SessionPreset.preferred(for: .bIsometrics, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(seated.id, "ext")
        XCTAssertEqual(seated.label, "Seated leg extension")
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
        XCTAssertEqual(seated.label, "Seated leg extension")
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
        XCTAssertEqual(phaseB.map(\.label), ["Seated leg extension", "Leg press"])

        let phaseA = SessionPreset.forPhase(.aFlareDeLoad, primaryLoadID: PrimaryLoadCatalog.legPress.id)
        XCTAssertEqual(phaseA.map(\.id), ["lp-iso", "ext"])

        let phaseC = SessionPreset.forPhase(.cHeavySlowResistance, primaryLoadID: PrimaryLoadCatalog.seatedExtension.id)
        XCTAssertEqual(phaseC.map(\.id), ["ke", "lp"])
    }

    func testPresetsAreTheFourKneeLoadersOnly() {
        // Phases D/E are gone, and with them the landings / tennis chips.
        let knee = SessionPreset.all.filter { $0.injuryID == InjuryCatalog.patellarTendinopathy.id }
        XCTAssertEqual(knee.map(\.id), ["ext", "ke", "lp-iso", "lp"])
        XCTAssertFalse(SessionPreset.all.contains { $0.id == "land" || $0.id == "hit" || $0.id == "match" })
        for preset in SessionPreset.all {
            XCTAssertNotNil(preset.phases, preset.id)
            XCTAssertTrue(preset.phases?.isSubset(of: Set(RehabPhase.allCases)) == true, preset.id)
        }
        for phase in RehabPhase.allCases {
            XCTAssertEqual(SessionPreset.forPhase(phase).count, 2, "\(phase) shows both loaders")
        }
    }

    func testNextUpCTAResumesTheLiftWhenADraftExists() {
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.nextUpCTA(hasDraft: false), "Log Workout")
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.nextUpCTA(hasDraft: true), "Resume seated leg extension")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.nextUpCTA(hasDraft: false), "Log leg press")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.nextUpCTA(hasDraft: true), "Resume leg press")
    }
}
