import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestPermissions() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func registerAlarmCategories() {
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze", options: [])
        let dismiss = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [.destructive])
        let openMathLock = UNNotificationAction(identifier: "OPEN_MATH_LOCK", title: "Open Math Lock", options: [.foreground])

        let standard = UNNotificationCategory(
            identifier: "ALARM_STANDARD",
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: []
        )

        let strict = UNNotificationCategory(
            identifier: "ALARM_STRICT",
            actions: [openMathLock],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([standard, strict])
    }

    func scheduleStateMachineNotifications(
        alarm: AlarmSchedule,
        stateMachine: AlarmStateMachine,
        maxMissedRetries: Int = 2
    ) async {
        await cancelNotifications(for: alarm.id)

        let checkPoints = stateMachine.fallbackCheckpoints(initialFireAt: alarm.scheduledAt)
        for checkpoint in checkPoints {
            await scheduleCheckpoint(alarm: alarm, checkpoint: checkpoint)
        }

        if alarm.alarmKind == .wakeForWork || alarm.alarmKind == .finalEmergency {
            let missedRetries = stateMachine.missedCriticalRetries(
                from: alarm.scheduledAt.addingTimeInterval(15 * 60),
                maxRetries: max(0, maxMissedRetries)
            )
            for (index, retryDate) in missedRetries.enumerated() {
                await scheduleRetry(alarm: alarm, date: retryDate, index: index + 1)
            }
        }
    }

    func cancelNotifications(for alarmId: UUID) async {
        var ids = [
            "\(alarmId.uuidString)-main",
            "\(alarmId.uuidString)-esc1",
            "\(alarmId.uuidString)-emergency",
            "\(alarmId.uuidString)-missed",
            "\(alarmId.uuidString)-retry1",
            "\(alarmId.uuidString)-retry2"
        ]

        for retry in 3...5 {
            ids.append("\(alarmId.uuidString)-retry\(retry)")
        }

        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func scheduleCheckpoint(alarm: AlarmSchedule, checkpoint: AlarmFallbackCheckpoint) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.label
        content.body = checkpoint.message
        content.sound = .default
        content.categoryIdentifier = strictCategoryIfNeeded(for: alarm.alarmKind)
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "state": checkpoint.state.rawValue
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, checkpoint.fireAt.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationId(for: alarm.id, state: checkpoint.state),
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func scheduleRetry(alarm: AlarmSchedule, date: Date, index: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Missed critical work alarm"
        content.body = "Retry \(index): open app and resolve alarm now."
        content.sound = .default
        content.categoryIdentifier = "ALARM_STRICT"
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "state": AlarmState.failureMissed.rawValue,
            "retryIndex": index
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(alarm.id.uuidString)-retry\(index)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func notificationId(for alarmId: UUID, state: AlarmState) -> String {
        switch state {
        case .mainAlarm:
            return "\(alarmId.uuidString)-main"
        case .escalation1:
            return "\(alarmId.uuidString)-esc1"
        case .emergency:
            return "\(alarmId.uuidString)-emergency"
        case .failureMissed:
            return "\(alarmId.uuidString)-missed"
        default:
            return "\(alarmId.uuidString)-\(state.rawValue.lowercased())"
        }
    }

    private func strictCategoryIfNeeded(for kind: AlarmKind) -> String {
        switch kind {
        case .wakeForWork, .finalEmergency:
            return "ALARM_STRICT"
        default:
            return "ALARM_STANDARD"
        }
    }
}
