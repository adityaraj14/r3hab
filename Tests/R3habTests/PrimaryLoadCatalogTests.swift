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

    func testCatalogIsOnlySeatedExtensionAndLegPress() {
        let options = PrimaryLoadCatalog.all
        XCTAssertEqual(options.map(\.id), ["seated-extension", "leg-press"])
        XCTAssertEqual(options.map(\.title), ["Seated extension", "Leg press"])
        XCTAssertFalse(options.contains { $0.title.contains("HSR") })
        XCTAssertFalse(PrimaryLoadCatalog.contains("spanish-squat"))
        XCTAssertFalse(PrimaryLoadCatalog.contains("wall-sit"))
        XCTAssertFalse(PrimaryLoadCatalog.contains("ql-hip-thrust"))
        XCTAssertFalse(PrimaryLoadCatalog.contains("ql-side-bend"))
        XCTAssertFalse(PrimaryLoadCatalog.contains("ql-walk"))
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

    func testRemovedQLLoadsRemapToSeatedExtension() {
        for retired in ["ql-hip-thrust", "ql-side-bend", "ql-walk"] {
            XCTAssertEqual(PrimaryLoadCatalog.normalizedID(retired), PrimaryLoadCatalog.seatedExtension.id, retired)
            XCTAssertTrue(PrimaryLoadCatalog.needsRemap(retired), retired)
        }
        XCTAssertFalse(SessionPreset.all.contains { $0.id.hasPrefix("ql-") })
        XCTAssertFalse(SessionPreset.all.contains { $0.label.localizedCaseInsensitiveContains("walk") })
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

    func testPresetsAreTheFourKneeLoadersOnly() {
        // Phases D/E are gone, and with them the landings / tennis chips.
        XCTAssertEqual(SessionPreset.all.map(\.id), ["ext", "ke", "lp-iso", "lp"])
        XCTAssertFalse(SessionPreset.all.contains { $0.id == "land" || $0.id == "hit" || $0.id == "match" })
        for preset in SessionPreset.all {
            XCTAssertNotNil(preset.phases, preset.id)
            XCTAssertTrue(preset.phases?.isSubset(of: Set(RehabPhase.allCases)) == true, preset.id)
        }
        for phase in RehabPhase.allCases {
            XCTAssertEqual(SessionPreset.forPhase(phase).count, 2, "\(phase) shows both loaders")
        }
    }

    func testChartVolumeTitleKeepsSeatedExtensionLabel() {
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.chartVolumeTitle, "Seated extension volume")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.chartVolumeTitle, "Leg press volume")
    }

    func testNextUpCTAResumesTheLiftWhenADraftExists() {
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.nextUpCTA(hasDraft: false), "Log seated extension")
        XCTAssertEqual(PrimaryLoadCatalog.seatedExtension.nextUpCTA(hasDraft: true), "Resume seated extension")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.nextUpCTA(hasDraft: false), "Log leg press")
        XCTAssertEqual(PrimaryLoadCatalog.legPress.nextUpCTA(hasDraft: true), "Resume leg press")
    }
}
