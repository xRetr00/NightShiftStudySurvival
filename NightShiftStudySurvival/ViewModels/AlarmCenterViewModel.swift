import Foundation
import SwiftData

@MainActor
final class AlarmCenterViewModel: ObservableObject {
    @Published private(set) var activeAlarms: [AlarmSchedule] = []

    private let context: ModelContext
    private let stateMachine = AlarmStateMachine()
    private let notificationScheduler = NotificationScheduler()

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<AlarmSchedule>(sortBy: [SortDescriptor(\.scheduledAt)])
        activeAlarms = ((try? context.fetch(descriptor)) ?? []).filter { !$0.isCompleted && !$0.isFailed }
        applyAdaptiveMathDifficultyIfEnabled()
    }

    func createAlarm(kind: AlarmKind, label: String, fireAt: Date) {
        let initialState: AlarmState = .preAlarm
        let expiresAt = stateMachine.expiryDate(for: initialState, kind: kind, from: fireAt)

        let alarm = AlarmSchedule(
            label: label,
            alarmKind: kind,
            currentState: initialState,
            scheduledAt: fireAt,
            enteredCurrentStateAt: fireAt,
            expiresCurrentStateAt: expiresAt,
            previousStateRaw: nil,
            triggerReasonRaw: AlarmTransitionCause.timerExpired.rawValue,
            userActionContext: "created",
            notificationDeliveryState: "scheduled"
        )

        context.insert(alarm)
        try? context.save()

        let settings = fetchSettings()
        Task {
            _ = await notificationScheduler.requestPermissions()
            notificationScheduler.registerAlarmCategories()
            await notificationScheduler.scheduleStateMachineNotifications(
                alarm: alarm,
                stateMachine: stateMachine,
                maxMissedRetries: settings?.maxMissedAlarmRetries ?? 2
            )
        }

        refresh()
    }

    private func fetchSettings() -> AppSettings? {
        (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
    }

    private func applyAdaptiveMathDifficultyIfEnabled() {
        guard let settings = fetchSettings(), settings.autoAdjustMathDifficulty else {
            return
        }

        let alarms = (try? context.fetch(FetchDescriptor<AlarmSchedule>(sortBy: [SortDescriptor(\.scheduledAt, order: .reverse)]))) ?? []
        let strict = alarms.filter { $0.alarmKind == .wakeForWork || $0.alarmKind == .finalEmergency }
        let sample = Array(strict.prefix(12))
        guard sample.count >= 4 else { return }

        let missed = sample.filter(\.isFailed).count
        let missRate = Double(missed) / Double(sample.count)
        let overrides = sample.filter(\.overrideUsed).count

        let current = settings.mathDifficulty
        let updated: String

        if missRate >= 0.35 || overrides >= 2 {
            updated = harderDifficulty(from: current)
        } else if missRate <= 0.05, overrides == 0 {
            updated = easierDifficulty(from: current)
        } else {
            updated = current
        }

        if updated != current {
            settings.mathDifficulty = updated
            settings.updatedAt = .now
            try? context.save()
        }
    }

    private func harderDifficulty(from value: String) -> String {
        switch value.lowercased() {
        case "easy": return "Medium"
        case "medium": return "Brutal"
        default: return "Brutal"
        }
    }

    private func easierDifficulty(from value: String) -> String {
        switch value.lowercased() {
        case "brutal": return "Medium"
        case "medium": return "Easy"
        default: return "Easy"
        }
    }
}
