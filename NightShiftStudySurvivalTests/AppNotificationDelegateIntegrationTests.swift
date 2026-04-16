import XCTest
import SwiftData
@testable import NightShiftStudySurvival

@MainActor
final class AppNotificationDelegateIntegrationTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Subject.self,
            ClassSession.self,
            AppSettings.self,
            SleepRecommendation.self,
            SleepBlock.self,
            SleepExecutionLog.self,
            AlarmSchedule.self,
            AlarmTransitionLog.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

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

    func testHandleMockResponseSnoozeExtendsExpiry() throws {
        let context = try makeContext()
        let delegate = AppNotificationDelegate.shared
        delegate.configure(context: context)

        let now = Date()
        let initialExpiry = now.addingTimeInterval(30)
        let alarm = AlarmSchedule(
            label: "Mock alarm",
            alarmKind: .wakeForClass,
            currentState: .preAlarm,
            scheduledAt: now,
            enteredCurrentStateAt: now,
            expiresCurrentStateAt: initialExpiry
        )
        context.insert(alarm)
        try? context.save()

        let processed = delegate.handleMockResponse(
            alarmId: alarm.id,
            actionIdentifier: "SNOOZE",
            now: now
        )

        XCTAssertTrue(processed)
        XCTAssertEqual(alarm.expiresCurrentStateAt, initialExpiry.addingTimeInterval(60))
        XCTAssertEqual(alarm.userActionContext, AlarmUserAction.snooze.rawValue)
    }

    func testHandleMockResponseTransitionsWorkAlarmToMathLock() throws {
        let context = try makeContext()
        let delegate = AppNotificationDelegate.shared
        delegate.configure(context: context)

        let now = Date()
        let alarm = AlarmSchedule(
            label: "Work strict alarm",
            alarmKind: .wakeForWork,
            currentState: .escalation2,
            scheduledAt: now,
            enteredCurrentStateAt: now,
            expiresCurrentStateAt: now.addingTimeInterval(60)
        )
        context.insert(alarm)
        try? context.save()

        let processed = delegate.handleMockResponse(
            alarmId: alarm.id,
            actionIdentifier: "OPEN_MATH_LOCK",
            now: now
        )

        XCTAssertTrue(processed)
        XCTAssertEqual(alarm.currentState, .mathLock)
        XCTAssertEqual(alarm.notificationDeliveryState, "updated-from-notification")
    }
}
