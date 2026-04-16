import XCTest
@testable import NightShiftStudySurvival

final class AlarmStateMachineTests: XCTestCase {
    func testStrictAlarmEscalatesToMainOnTimerExpiry() {
        let machine = AlarmStateMachine()

        let result = machine.nextState(
            currentState: .preAlarm,
            kind: .wakeForWork,
            cause: .timerExpired,
            userAction: nil
        )

        XCTAssertEqual(result.toState, .mainAlarm)
        XCTAssertFalse(result.shouldMarkCompleted)
        XCTAssertFalse(result.shouldMarkFailed)
    }

    func testWorkAlarmDismissDoesNotCompleteEarly() {
        let machine = AlarmStateMachine()

        let result = machine.nextState(
            currentState: .mainAlarm,
            kind: .wakeForWork,
            cause: .userActionValid,
            userAction: .dismiss
        )

        XCTAssertEqual(result.toState, .mainAlarm)
        XCTAssertFalse(result.shouldMarkCompleted)
    }

    func testMathLockSolvedTransitionsToCompletion() {
        let machine = AlarmStateMachine()

        let result = machine.nextState(
            currentState: .mathLock,
            kind: .wakeForWork,
            cause: .mathSolved,
            userAction: .answerMath
        )

        XCTAssertEqual(result.toState, .completion)
        XCTAssertTrue(result.shouldMarkCompleted)
    }
}
