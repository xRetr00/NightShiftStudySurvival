import Foundation

enum AttendanceMode: String, Codable, CaseIterable, Identifiable {
    case dvz = "DVZ"
    case dm = "DM"
    case normal = "Normal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dvz:
            return "Mandatory"
        case .dm:
            return "Optional"
        case .normal:
            return "Normal"
        }
    }
}

enum DayType: String, Codable, CaseIterable, Identifiable {
    case heavy = "Heavy Day"
    case medium = "Medium Day"
    case light = "Light Day"
    case recovery = "Recovery Day"

    var id: String { rawValue }
}

enum AlarmKind: String, Codable, CaseIterable, Identifiable {
    case wakeForClass = "Wake for Class"
    case wakeForWork = "Wake for Work"
    case sleepReminder = "Sleep Reminder"
    case leaveHomeForClass = "Leave Home for Class"
    case leaveHomeForWork = "Leave Home for Work"
    case finalEmergency = "Final Emergency"

    var id: String { rawValue }
}

enum AlarmState: String, Codable, CaseIterable, Identifiable {
    case preAlarm = "PreAlarm"
    case mainAlarm = "MainAlarm"
    case escalation1 = "Escalation1"
    case escalation2 = "Escalation2"
    case emergency = "Emergency"
    case mathLock = "MathLock"
    case completion = "Completion"
    case failureMissed = "FailureMissed"

    var id: String { rawValue }
}

enum AlarmTransitionCause: String, Codable, CaseIterable {
    case timerExpired
    case userActionValid
    case userActionInvalid
    case maxSnoozeReached
    case appUnopenedDeadline
    case mathSolved
    case emergencyOverride
    case abandonmentTimeout
    case forceFailure
}

enum AlarmUserAction: String, Codable, CaseIterable, Identifiable {
    case openApp
    case snooze
    case acknowledge
    case dismiss
    case startMathLock
    case answerMath
    case emergencyOverride

    var id: String { rawValue }
}

enum SleepStrategyLabel: String, Codable, CaseIterable, Identifiable {
    case emergencyMorningSleep = "Emergency morning sleep"
    case mainRecoverySleep = "Main recovery sleep"
    case shortPreWorkReset = "Short pre-work reset"
    case heavySurvivalDay = "Heavy survival day"
    case recoveryDay = "Recovery day"

    var id: String { rawValue }
}

enum SleepExecutionStatus: String, Codable, CaseIterable, Identifiable {
    case followed = "Followed"
    case ignored = "Ignored"

    var id: String { rawValue }
}

enum HapticPattern: String, Codable {
    case lightPulse
    case mediumDoubleTap
    case strongPulse
    case rampBurst
    case criticalLongPulse
    case none
}

enum SoundProfile: String, Codable {
    case gentleLoop
    case standardLoop
    case loudFastLoop
    case aggressiveAlternating
    case emergencyMax
    case mathLockUrgent
    case silent
}
