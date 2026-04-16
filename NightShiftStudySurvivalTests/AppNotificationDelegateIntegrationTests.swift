import XCTest
@testable import NightShiftStudySurvival

@MainActor
final class AppNotificationDelegateIntegrationTests: XCTestCase {
    func testDelegateDecisionUsesRouterForSnooze() {
        let delegate = AppNotificationDelegate.shared
        let decision = delegate.decisionForActionIdentifier("SNOOZE")

        XCTAssertEqual(decision.userAction, .snooze)
        XCTAssertEqual(decision.cause, .userActionValid)
    }

    func testDelegateDecisionUsesRouterForMathLock() {
        let delegate = AppNotificationDelegate.shared
        let decision = delegate.decisionForActionIdentifier("OPEN_MATH_LOCK")

        XCTAssertEqual(decision.userAction, .startMathLock)
    }

    func testDelegateDecisionUsesRouterDefaultPath() {
        let delegate = AppNotificationDelegate.shared
        let decision = delegate.decisionForActionIdentifier("WHATEVER")

        XCTAssertEqual(decision.userAction, .openApp)
    }
}
