import Foundation
import SwiftData

@MainActor
final class ActiveAlarmSessionViewModel: ObservableObject {
    @Published private(set) var state: AlarmState
    @Published private(set) var definition: AlarmStateDefinition
    @Published private(set) var timeRemaining: Int = 0
    @Published private(set) var consecutiveCorrect: Int = 0
    @Published private(set) var attempts: Int = 0
    @Published private(set) var statusText: String = ""
    @Published var answerInput: String = ""
    @Published private(set) var currentChallenge: MathChallenge?

    private let context: ModelContext
    private let alarm: AlarmSchedule
    private let stateMachine = AlarmStateMachine()
    private let mathEngine = MathChallengeEngine()
    private let feedback = AlarmFeedbackService.shared
    private var logger: AlarmTransitionLogger
    private var timer: Timer?
    private var snoozeCount = 0
    private var lastInteractionAt: Date = .now
    private var settings: AppSettings?

    private let abandonmentTimeout: TimeInterval = 3 * 60

    init(context: ModelContext, alarm: AlarmSchedule) {
        self.context = context
        self.alarm = alarm
        self.state = alarm.currentState
        self.definition = stateMachine.definition(for: alarm.currentState, kind: alarm.alarmKind)
        self.logger = AlarmTransitionLogger(context: context)

        self.settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first

        if state == .mathLock {
            generateChallenge()
        }

        recalculateRemaining()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        lastInteractionAt = .now

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        applyFeedbackForCurrentState()

        statusText = "Alarm active: \(state.rawValue)"
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        feedback.stop()
    }

    func perform(action: AlarmUserAction) {
        lastInteractionAt = .now

        if action == .snooze {
            snoozeCount += 1
            if snoozeCount >= maxSnoozesAllowed() {
                transition(cause: .maxSnoozeReached, userAction: .snooze)
                return
            }

            // Snooze extends current state timeout by 60 seconds.
            if let expiry = alarm.expiresCurrentStateAt {
                alarm.expiresCurrentStateAt = expiry.addingTimeInterval(60)
                recalculateRemaining()
                statusText = "Snoozed for 1 minute"
                try? context.save()
            }
            return
        }

        switch action {
        case .dismiss, .acknowledge, .startMathLock:
            transition(cause: .userActionValid, userAction: action)
        case .emergencyOverride:
            alarm.overrideUsed = true
            transition(cause: .emergencyOverride, userAction: action)
        default:
            break
        }
    }

    func submitMathAnswer() {
        guard state == .mathLock, let challenge = currentChallenge else { return }
        lastInteractionAt = .now
        attempts += 1

        guard let typed = Int(answerInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            statusText = "Invalid input. Enter a number."
            return
        }

        if typed == challenge.answer {
            consecutiveCorrect += 1
            statusText = "Correct (\(consecutiveCorrect)/\(requiredCorrectAnswers()))."
            answerInput = ""

            if consecutiveCorrect >= requiredCorrectAnswers() {
                transition(cause: .mathSolved, userAction: .answerMath)
                return
            }

            generateChallenge()
        } else {
            consecutiveCorrect = 0
            statusText = "Wrong answer. Sequence reset."
            answerInput = ""
            generateChallenge()
        }
    }

    var allowsEmergencyOverride: Bool {
        guard state == .mathLock || state == .emergency else { return false }
        return Date().timeIntervalSince(alarm.enteredCurrentStateAt) >= 90
    }

    private func tick() {
        recalculateRemaining()

        if let expiry = alarm.expiresCurrentStateAt, Date() >= expiry {
            transition(cause: .timerExpired, userAction: nil)
            return
        }

        if (state == .emergency || state == .mathLock) && Date().timeIntervalSince(lastInteractionAt) >= abandonmentTimeout {
            transition(cause: .abandonmentTimeout, userAction: nil)
        }
    }

    private func transition(cause: AlarmTransitionCause, userAction: AlarmUserAction?) {
        let from = state
        let plannedAt = alarm.expiresCurrentStateAt ?? Date()
        let actual = Date()

        let result = stateMachine.nextState(
            currentState: from,
            kind: alarm.alarmKind,
            cause: cause,
            userAction: userAction
        )

        guard result.toState != from || result.shouldMarkCompleted || result.shouldMarkFailed else {
            return
        }

        alarm.currentState = result.toState
        alarm.previousStateRaw = from.rawValue
        alarm.triggerReasonRaw = cause.rawValue
        alarm.userActionContext = userAction?.rawValue ?? cause.rawValue
        alarm.enteredCurrentStateAt = actual
        alarm.expiresCurrentStateAt = stateMachine.expiryDate(for: result.toState, kind: alarm.alarmKind, from: actual)
        alarm.isCompleted = result.shouldMarkCompleted
        alarm.isFailed = result.shouldMarkFailed
        alarm.updatedAt = .now

        logger.logTransition(
            alarm: alarm,
            from: from,
            to: result.toState,
            cause: cause,
            plannedAt: plannedAt,
            actualAt: actual,
            appForegroundState: "foreground",
            notificationDeliveryState: alarm.notificationDeliveryState,
            userAction: userAction,
            solveAttempts: attempts,
            overrideUsed: alarm.overrideUsed
        )

        state = result.toState
        definition = stateMachine.definition(for: state, kind: alarm.alarmKind)
        recalculateRemaining()
        applyFeedbackForCurrentState()

        if state == .mathLock {
            generateChallenge()
        }

        if state == .completion {
            statusText = "Alarm completed"
            stop()
        } else if state == .failureMissed {
            statusText = "Alarm missed"
            stop()
        } else {
            statusText = "Transitioned to \(state.rawValue)"
        }

        try? context.save()
    }

    private func recalculateRemaining() {
        guard let expires = alarm.expiresCurrentStateAt else {
            timeRemaining = 0
            return
        }

        let remaining = Int(expires.timeIntervalSinceNow)
        timeRemaining = max(0, remaining)
    }

    private func generateChallenge() {
        currentChallenge = mathEngine.nextChallenge(difficulty: settings?.mathDifficulty ?? "Medium")
    }

    private func requiredCorrectAnswers() -> Int {
        max(1, settings?.requiredCorrectMathAnswers ?? 3)
    }

    private func maxSnoozesAllowed() -> Int {
        switch alarm.alarmKind {
        case .wakeForWork, .finalEmergency:
            return 1
        default:
            return 2
        }
    }

    private func applyFeedbackForCurrentState() {
        guard state != .completion, state != .failureMissed else {
            feedback.stop()
            return
        }

        feedback.start(
            sound: definition.soundProfile,
            haptics: definition.hapticPattern,
            strongHapticsEnabled: settings?.enableStrongHaptics ?? true,
            soundStyle: settings?.alarmSoundStyle ?? "Default",
            loudnessProfile: settings?.alarmLoudnessProfile ?? "High"
        )
    }
}
