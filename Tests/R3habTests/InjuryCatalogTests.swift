import XCTest
@testable import R3hab

final class InjuryCatalogTests: XCTestCase {
    func testSelectableOptionsAreTheThreeKneeLabels() {
        let ids = InjuryCatalog.selectable.map(\.id)
        XCTAssertEqual(ids, [
            "jumpers-knee",
            "patellar-tendinopathy",
            "patellar-tendonitis"
        ])
        XCTAssertEqual(InjuryCatalog.selectable.map(\.title), [
            "Jumper's knee",
            "Patellar tendinopathy",
            "Patellar tendonitis"
        ])
    }

    func testEverySelectableMapsToKneeProtocol() {
        for injury in InjuryCatalog.selectable {
            XCTAssertEqual(injury.protocolTrack, .knee)
            XCTAssertTrue(injury.isSelectable)
        }
    }

    func testCatalogHasNoBackOrQLEntries() {
        let blob = InjuryCatalog.all
            .map { "\($0.id) \($0.title) \($0.subtitle)" }
            .joined(separator: " ")
            .lowercased()
        XCTAssertFalse(blob.contains("ql"))
        XCTAssertFalse(blob.contains("low-back"))
        XCTAssertFalse(blob.contains("low back"))
        XCTAssertFalse(blob.contains("lower back"))
    }

    func testUnknownIdFallsBackToPatellarTendinopathy() {
        let fallback = InjuryCatalog.definition(for: "future-achilles")
        XCTAssertEqual(fallback.id, InjuryCatalog.defaultSelectable.id)
        XCTAssertEqual(InjuryCatalog.normalizedID("not-a-real-injury"), "patellar-tendinopathy")
    }

    func testSkipLandsInPhaseBWithNotificationsOff() {
        let skipped = OnboardingCompletion.result(
            skipped: true,
            phase: .aFlareDeLoad,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.jumpersKnee.id
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertFalse(skipped.notificationsEnabled)
        XCTAssertEqual(skipped.injuryID, InjuryCatalog.defaultSelectable.id)
        XCTAssertEqual(skipped.protocolTrack, .knee)
    }

    func testCompleteKeepsChosenInjuryAndPhase() {
        let chosen = OnboardingCompletion.result(
            skipped: false,
            phase: .cHeavySlowResistance,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.patellarTendonitis.id
        )
        XCTAssertEqual(chosen.phase, .cHeavySlowResistance)
        XCTAssertTrue(chosen.notificationsEnabled)
        XCTAssertEqual(chosen.injuryID, "patellar-tendonitis")
        XCTAssertEqual(chosen.protocolTrack, .knee)
    }
}
