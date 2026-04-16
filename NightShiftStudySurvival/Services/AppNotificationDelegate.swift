import Foundation
import SwiftData
import UserNotifications

@MainActor
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    private var context: ModelContext?
    private let stateMachine = AlarmStateMachine()
    private let actionRouter = NotificationActionRouter()

    private override init() {
        super.init()
    }

    func configure(context: ModelContext) {
        self.context = context
    }

    func decisionForActionIdentifier(_ actionIdentifier: String) -> NotificationActionDecision {
        actionRouter.decision(for: actionIdentifier)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await self.handleNotificationResponse(response)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        guard let context else { return }
        guard let alarmIdString = response.notification.request.content.userInfo["alarmId"] as? String,
              let alarmId = UUID(uuidString: alarmIdString) else {
            return
        }

        let descriptor = FetchDescriptor<AlarmSchedule>()
        guard let alarm = (try? context.fetch(descriptor))?.first(where: { $0.id == alarmId }) else {
            return
        }

        let logger = AlarmTransitionLogger(context: context)
        let from = alarm.currentState
        let plannedAt = alarm.expiresCurrentStateAt ?? Date()
        let now = Date()

        let decision = actionRouter.decision(for: response.actionIdentifier)

        if decision.userAction == .snooze {
            let newExpiry = (alarm.expiresCurrentStateAt ?? now).addingTimeInterval(60)
            alarm.expiresCurrentStateAt = newExpiry
            alarm.userActionContext = AlarmUserAction.snooze.rawValue
            alarm.notificationDeliveryState = "snoozed-from-notification"
            alarm.updatedAt = .now

            logger.logTransition(
                alarm: alarm,
                from: from,
                to: from,
                cause: .userActionValid,
                plannedAt: plannedAt,
                actualAt: now,
                appForegroundState: "notification",
                notificationDeliveryState: alarm.notificationDeliveryState,
                userAction: .snooze
            )
        } else {
            applyTransition(
                alarm: alarm,
                from: from,
                cause: decision.cause,
                userAction: decision.userAction,
                logger: logger,
                plannedAt: plannedAt,
                actualAt: now
            )
        }

        try? context.save()
    }

    private func applyTransition(
        alarm: AlarmSchedule,
        from: AlarmState,
        cause: AlarmTransitionCause,
        userAction: AlarmUserAction,
        logger: AlarmTransitionLogger,
        plannedAt: Date,
        actualAt: Date
    ) {
        let result = stateMachine.nextState(
            currentState: from,
            kind: alarm.alarmKind,
            cause: cause,
            userAction: userAction
        )

        let toState: AlarmState
        let causeToLog: AlarmTransitionCause
        if result.toState == from && !result.shouldMarkCompleted && !result.shouldMarkFailed {
            toState = from
            causeToLog = .userActionInvalid
        } else {
            toState = result.toState
            causeToLog = cause

            alarm.currentState = toState
            alarm.previousStateRaw = from.rawValue
            alarm.triggerReasonRaw = cause.rawValue
            alarm.userActionContext = userAction.rawValue
            alarm.notificationDeliveryState = "updated-from-notification"
            alarm.enteredCurrentStateAt = actualAt
            alarm.expiresCurrentStateAt = stateMachine.expiryDate(for: toState, kind: alarm.alarmKind, from: actualAt)
            alarm.isCompleted = result.shouldMarkCompleted
            alarm.isFailed = result.shouldMarkFailed
            alarm.updatedAt = .now
        }

        logger.logTransition(
            alarm: alarm,
            from: from,
            to: toState,
            cause: causeToLog,
            plannedAt: plannedAt,
            actualAt: actualAt,
            appForegroundState: "notification",
            notificationDeliveryState: alarm.notificationDeliveryState,
            userAction: userAction,
            solveAttempts: 0,
            overrideUsed: alarm.overrideUsed
        )
    }
}
