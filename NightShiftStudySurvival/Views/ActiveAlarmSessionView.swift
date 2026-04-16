import SwiftUI
import SwiftData

struct ActiveAlarmSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveAlarmSessionViewModel

    let alarmLabel: String

    init(context: ModelContext, alarm: AlarmSchedule) {
        _viewModel = StateObject(wrappedValue: ActiveAlarmSessionViewModel(context: context, alarm: alarm))
        self.alarmLabel = alarm.label
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(alarmLabel)
                .font(.title.bold())
                .foregroundStyle(.white)

            Text(viewModel.state.rawValue)
                .font(.title2.weight(.semibold))
                .foregroundStyle(stateColor(viewModel.state))

            if viewModel.timeRemaining > 0 {
                Text("Time left: \(viewModel.timeRemaining)s")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            detailsCard

            if viewModel.state == .mathLock {
                mathLockCard
            }

            actionButtons

            Text(viewModel.statusText)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))

            if viewModel.state == .completion || viewModel.state == .failureMissed {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.info))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sound: \(viewModel.definition.soundProfile.rawValue)")
            Text("Haptics: \(viewModel.definition.hapticPattern.rawValue)")
            Text("Allowed actions: \(viewModel.definition.allowedActions.map(\.rawValue).joined(separator: ", "))")
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }

    private var mathLockCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Math Lock")
                .font(.headline)
                .foregroundStyle(AppTheme.critical)

            Text(viewModel.currentChallenge?.prompt ?? "Loading challenge...")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            TextField("Answer", text: $viewModel.answerInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Correct in sequence: \(viewModel.consecutiveCorrect)")
                Spacer()
                Text("Attempts: \(viewModel.attempts)")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))

            Button("Submit answer") {
                viewModel.submitMathAnswer()
            }
            .buttonStyle(SurvivalButtonStyle(color: AppTheme.warning))

            if viewModel.allowsEmergencyOverride {
                Button("Emergency override") {
                    viewModel.perform(action: .emergencyOverride)
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.critical))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if viewModel.definition.allowedActions.contains(.acknowledge) {
                Button("Acknowledge") {
                    viewModel.perform(action: .acknowledge)
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.safe))
            }

            if viewModel.definition.allowedActions.contains(.dismiss) {
                Button("Dismiss") {
                    viewModel.perform(action: .dismiss)
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.safe))
            }

            if viewModel.definition.allowedActions.contains(.snooze) {
                Button("Snooze") {
                    viewModel.perform(action: .snooze)
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.warning))
            }

            if viewModel.definition.allowedActions.contains(.startMathLock) && viewModel.state != .mathLock {
                Button("Start Math Lock") {
                    viewModel.perform(action: .startMathLock)
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.critical))
            }
        }
    }

    private func stateColor(_ state: AlarmState) -> Color {
        switch state {
        case .preAlarm:
            return AppTheme.safe
        case .mainAlarm:
            return AppTheme.info
        case .escalation1, .escalation2:
            return AppTheme.warning
        case .emergency, .mathLock:
            return AppTheme.critical
        case .completion:
            return AppTheme.safe
        case .failureMissed:
            return AppTheme.critical
        }
    }
}
