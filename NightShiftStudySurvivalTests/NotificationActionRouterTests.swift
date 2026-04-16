import XCTest
@testable import NightShiftStudySurvival

final class NotificationActionRouterTests: XCTestCase {
    func testMapsSnoozeAction() {
        let router = NotificationActionRouter()
        let decision = router.decision(for: "SNOOZE")

        XCTAssertEqual(decision.userAction, .snooze)
        XCTAssertEqual(decision.cause, .userActionValid)
    }

    func testMapsDismissAction() {
        let router = NotificationActionRouter()
        let decision = router.decision(for: "DISMISS")

        XCTAssertEqual(decision.userAction, .dismiss)
    }

    func testMapsUnknownActionToOpenApp() {
        let router = NotificationActionRouter()
        let decision = router.decision(for: "UNKNOWN")

        XCTAssertEqual(decision.userAction, .openApp)
    }
}
