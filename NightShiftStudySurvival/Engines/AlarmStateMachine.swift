import Foundation

struct AlarmStateDefinition {
    let state: AlarmState
    let duration: TimeInterval?
    let soundProfile: SoundProfile
    let hapticPattern: HapticPattern
    let allowedActions: Set<AlarmUserAction>
}

struct AlarmFallbackCheckpoint: Identifiable {
    let id = UUID()
    let state: AlarmState
    let fireAt: Date
    let message: String
}

struct AlarmTransitionResult {
    let toState: AlarmState
    let shouldMarkCompleted: Bool
    let shouldMarkFailed: Bool
}

struct AlarmStateMachine {
    private let calendar = Calendar.current

    func definition(for state: AlarmState, kind: AlarmKind) -> AlarmStateDefinition {
        switch state {
        case .preAlarm:
            return AlarmStateDefinition(
                state: .preAlarm,
                duration: 2 * 60,
                soundProfile: .gentleLoop,
                hapticPattern: .lightPulse,
                allowedActions: [.openApp, .snooze, .acknowledge]
            )
        case .mainAlarm:
            return AlarmStateDefinition(
                state: .mainAlarm,
                duration: 3 * 60,
                soundProfile: .standardLoop,
                hapticPattern: .mediumDoubleTap,
                allowedActions: mainAlarmActions(for: kind)
            )
        case .escalation1:
            return AlarmStateDefinition(
                state: .escalation1,
                duration: 2 * 60,
                soundProfile: .loudFastLoop,
                hapticPattern: .strongPulse,
                allowedActions: escalation1Actions(for: kind)
            )
        case .escalation2:
            return AlarmStateDefinition(
                state: .escalation2,
                duration: 2 * 60,
                soundProfile: .aggressiveAlternating,
                hapticPattern: .rampBurst,
                allowedActions: escalation2Actions(for: kind)
            )
        case .emergency:
            return AlarmStateDefinition(
                state: .emergency,
                duration: nil,
                soundProfile: .emergencyMax,
                hapticPattern: .criticalLongPulse,
                allowedActions: emergencyActions(for: kind)
            )
        case .mathLock:
            return AlarmStateDefinition(
                state: .mathLock,
                duration: nil,
                soundProfile: .mathLockUrgent,
                hapticPattern: .strongPulse,
                allowedActions: [.answerMath, .emergencyOverride]
            )
        case .completion:
            return AlarmStateDefinition(
                state: .completion,
                duration: nil,
                soundProfile: .silent,
                hapticPattern: .none,
                allowedActions: []
            )
        case .failureMissed:
            return AlarmStateDefinition(
                state: .failureMissed,
                duration: nil,
                soundProfile: .silent,
                hapticPattern: .none,
                allowedActions: [.openApp]
            )
        }
    }

    func nextState(
        currentState: AlarmState,
        kind: AlarmKind,
        cause: AlarmTransitionCause,
        userAction: AlarmUserAction? = nil
    ) -> AlarmTransitionResult {
        switch currentState {
        case .preAlarm:
            if cause == .userActionValid, userAction == .acknowledge {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
            if cause == .timerExpired || cause == .appUnopenedDeadline || cause == .maxSnoozeReached {
                return .init(toState: .mainAlarm, shouldMarkCompleted: false, shouldMarkFailed: false)
            }
        case .mainAlarm:
            if cause == .userActionValid, userAction == .dismiss, isDismissAllowed(kind: kind) {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
            if cause == .timerExpired || cause == .appUnopenedDeadline || cause == .maxSnoozeReached {
                return .init(toState: .escalation1, shouldMarkCompleted: false, shouldMarkFailed: false)
            }
        case .escalation1:
            if cause == .userActionValid, userAction == .dismiss, isDismissAllowed(kind: kind) {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
            if cause == .timerExpired || cause == .appUnopenedDeadline {
                return .init(toState: .escalation2, shouldMarkCompleted: false, shouldMarkFailed: false)
            }
        case .escalation2:
            if isMathLockRequired(kind: kind), cause == .userActionValid, userAction == .startMathLock {
                return .init(toState: .mathLock, shouldMarkCompleted: false, shouldMarkFailed: false)
            }
            if !isMathLockRequired(kind: kind), cause == .userActionValid, userAction == .dismiss {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
            if cause == .timerExpired || cause == .appUnopenedDeadline {
                return .init(toState: .emergency, shouldMarkCompleted: false, shouldMarkFailed: false)
            }
        case .emergency:
            if isMathLockRequired(kind: kind) {
                if cause == .userActionValid, userAction == .startMathLock {
                    return .init(toState: .mathLock, shouldMarkCompleted: false, shouldMarkFailed: false)
                }
                if cause == .emergencyOverride {
                    return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
                }
            } else if cause == .userActionValid, userAction == .acknowledge {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
            if cause == .abandonmentTimeout || cause == .forceFailure {
                return .init(toState: .failureMissed, shouldMarkCompleted: false, shouldMarkFailed: true)
            }
        case .mathLock:
            if cause == .mathSolved {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
            if cause == .abandonmentTimeout || cause == .forceFailure {
                return .init(toState: .failureMissed, shouldMarkCompleted: false, shouldMarkFailed: true)
            }
            if cause == .emergencyOverride {
                return .init(toState: .completion, shouldMarkCompleted: true, shouldMarkFailed: false)
            }
        case .completion, .failureMissed:
            return .init(toState: currentState, shouldMarkCompleted: currentState == .completion, shouldMarkFailed: currentState == .failureMissed)
        }

        return .init(toState: currentState, shouldMarkCompleted: false, shouldMarkFailed: false)
    }

    func expiryDate(for state: AlarmState, kind: AlarmKind, from enteredAt: Date) -> Date? {
        guard let duration = definition(for: state, kind: kind).duration else {
            return nil
        }
        return enteredAt.addingTimeInterval(duration)
    }

    func fallbackCheckpoints(initialFireAt: Date) -> [AlarmFallbackCheckpoint] {
        [
            AlarmFallbackCheckpoint(
                state: .mainAlarm,
                fireAt: initialFireAt.addingTimeInterval(2 * 60),
                message: "Main alarm fallback"
            ),
            AlarmFallbackCheckpoint(
                state: .escalation1,
                fireAt: initialFireAt.addingTimeInterval(5 * 60),
                message: "Escalation 1 fallback"
            ),
            AlarmFallbackCheckpoint(
                state: .emergency,
                fireAt: initialFireAt.addingTimeInterval(9 * 60),
                message: "Emergency fallback"
            ),
            AlarmFallbackCheckpoint(
                state: .failureMissed,
                fireAt: initialFireAt.addingTimeInterval(15 * 60),
                message: "Missed alarm checkpoint"
            )
        ]
    }

    func missedCriticalRetries(from missedAt: Date, maxRetries: Int = 2) -> [Date] {
        let retryOffsets = [5 * 60, 10 * 60]
        return retryOffsets
            .prefix(maxRetries)
            .map { missedAt.addingTimeInterval(TimeInterval($0)) }
    }

    private func isMathLockRequired(kind: AlarmKind) -> Bool {
        kind == .wakeForWork || kind == .finalEmergency
    }

    private func isDismissAllowed(kind: AlarmKind) -> Bool {
        !isMathLockRequired(kind: kind)
    }

    private func mainAlarmActions(for kind: AlarmKind) -> Set<AlarmUserAction> {
        if isMathLockRequired(kind: kind) {
            return [.openApp, .snooze]
        }
        return [.openApp, .snooze, .dismiss]
    }

    private func escalation1Actions(for kind: AlarmKind) -> Set<AlarmUserAction> {
        if isMathLockRequired(kind: kind) {
            return [.openApp]
        }
        return [.openApp, .snooze, .dismiss]
    }

    private func escalation2Actions(for kind: AlarmKind) -> Set<AlarmUserAction> {
        if isMathLockRequired(kind: kind) {
            return [.openApp, .startMathLock]
        }
        return [.openApp, .dismiss]
    }

    private func emergencyActions(for kind: AlarmKind) -> Set<AlarmUserAction> {
        if isMathLockRequired(kind: kind) {
            return [.startMathLock, .emergencyOverride]
        }
        return [.acknowledge]
    }
}
