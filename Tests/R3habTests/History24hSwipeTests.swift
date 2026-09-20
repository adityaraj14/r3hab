import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class History24hSwipeTests: XCTestCase {
    func testDraftHasNoSwipe() {
        XCTAssertNil(History24hSwipe.action(isDraft: true, response24h: .pending))
        XCTAssertNil(History24hSwipe.action(isDraft: true, response24h: .better))
    }

    func testPendingShowsResolve() {
        XCTAssertEqual(
            History24hSwipe.action(isDraft: false, response24h: .pending),
            .resolve
        )
    }

    func testResolvedShowsEdit() {
        XCTAssertEqual(History24hSwipe.action(isDraft: false, response24h: .better), .edit)
        XCTAssertEqual(History24hSwipe.action(isDraft: false, response24h: .same), .edit)
        XCTAssertEqual(History24hSwipe.action(isDraft: false, response24h: .worse), .edit)
        XCTAssertEqual(History24hSwipe.action(isDraft: false, response24h: .notApplicable), .edit)
    }
}
