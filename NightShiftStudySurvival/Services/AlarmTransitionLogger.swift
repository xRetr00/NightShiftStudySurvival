import Foundation
import SwiftData

@MainActor
final class AlarmTransitionLogger {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func logTransition(
        alarm: AlarmSchedule,
        from: AlarmState,
        to: AlarmState,
        cause: AlarmTransitionCause,
        plannedAt: Date,
        actualAt: Date,
        appForegroundState: String,
        notificationDeliveryState: String,
        userAction: AlarmUserAction? = nil,
        solveAttempts: Int = 0,
        overrideUsed: Bool = false
    ) {
        let drift = Int(actualAt.timeIntervalSince(plannedAt) * 1000)

        let transition = AlarmTransitionLog(
            fromState: from,
            toState: to,
            transitionCause: cause,
            plannedAt: plannedAt,
            actualAt: actualAt,
            appForegroundState: appForegroundState,
            notificationDeliveryState: notificationDeliveryState,
            userActionRaw: userAction?.rawValue,
            solveAttempts: solveAttempts,
            overrideUsed: overrideUsed,
            driftMillis: drift,
            alarm: alarm
        )

        alarm.previousStateRaw = from.rawValue
        alarm.currentStateRaw = to.rawValue
        alarm.triggerReasonRaw = cause.rawValue
        alarm.enteredCurrentStateAt = actualAt
        alarm.updatedAt = .now
        alarm.transitions.append(transition)

        context.insert(transition)

        if to == .completion {
            alarm.isCompleted = true
        }
        if to == .failureMissed {
            alarm.isFailed = true
        }

        try? context.save()
    }
}
