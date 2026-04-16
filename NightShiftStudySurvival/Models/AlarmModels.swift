import Foundation
import SwiftData

@Model
final class AlarmSchedule {
    var id: UUID
    var label: String
    var alarmKindRaw: String
    var currentStateRaw: String
    var scheduledAt: Date
    var enteredCurrentStateAt: Date
    var expiresCurrentStateAt: Date?
    var previousStateRaw: String?
    var triggerReasonRaw: String?
    var userActionContext: String
    var notificationDeliveryState: String
    var isCompleted: Bool
    var isFailed: Bool
    var overrideUsed: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AlarmTransitionLog.alarm)
    var transitions: [AlarmTransitionLog]

    init(
        id: UUID = UUID(),
        label: String,
        alarmKind: AlarmKind,
        currentState: AlarmState,
        scheduledAt: Date,
        enteredCurrentStateAt: Date = .now,
        expiresCurrentStateAt: Date? = nil,
        previousStateRaw: String? = nil,
        triggerReasonRaw: String? = nil,
        userActionContext: String = "",
        notificationDeliveryState: String = "scheduled",
        isCompleted: Bool = false,
        isFailed: Bool = false,
        overrideUsed: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        transitions: [AlarmTransitionLog] = []
    ) {
        self.id = id
        self.label = label
        self.alarmKindRaw = alarmKind.rawValue
        self.currentStateRaw = currentState.rawValue
        self.scheduledAt = scheduledAt
        self.enteredCurrentStateAt = enteredCurrentStateAt
        self.expiresCurrentStateAt = expiresCurrentStateAt
        self.previousStateRaw = previousStateRaw
        self.triggerReasonRaw = triggerReasonRaw
        self.userActionContext = userActionContext
        self.notificationDeliveryState = notificationDeliveryState
        self.isCompleted = isCompleted
        self.isFailed = isFailed
        self.overrideUsed = overrideUsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transitions = transitions
    }

    var alarmKind: AlarmKind {
        get { AlarmKind(rawValue: alarmKindRaw) ?? .wakeForClass }
        set { alarmKindRaw = newValue.rawValue }
    }

    var currentState: AlarmState {
        get { AlarmState(rawValue: currentStateRaw) ?? .preAlarm }
        set { currentStateRaw = newValue.rawValue }
    }
}

@Model
final class AlarmTransitionLog {
    var id: UUID
    var fromStateRaw: String
    var toStateRaw: String
    var transitionCauseRaw: String
    var plannedAt: Date
    var actualAt: Date
    var appForegroundState: String
    var notificationDeliveryState: String
    var userActionRaw: String?
    var solveAttempts: Int
    var overrideUsed: Bool
    var driftMillis: Int

    var alarm: AlarmSchedule?

    init(
        id: UUID = UUID(),
        fromState: AlarmState,
        toState: AlarmState,
        transitionCause: AlarmTransitionCause,
        plannedAt: Date,
        actualAt: Date,
        appForegroundState: String,
        notificationDeliveryState: String,
        userActionRaw: String? = nil,
        solveAttempts: Int = 0,
        overrideUsed: Bool = false,
        driftMillis: Int,
        alarm: AlarmSchedule? = nil
    ) {
        self.id = id
        self.fromStateRaw = fromState.rawValue
        self.toStateRaw = toState.rawValue
        self.transitionCauseRaw = transitionCause.rawValue
        self.plannedAt = plannedAt
        self.actualAt = actualAt
        self.appForegroundState = appForegroundState
        self.notificationDeliveryState = notificationDeliveryState
        self.userActionRaw = userActionRaw
        self.solveAttempts = solveAttempts
        self.overrideUsed = overrideUsed
        self.driftMillis = driftMillis
        self.alarm = alarm
    }
}
