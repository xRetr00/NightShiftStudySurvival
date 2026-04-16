import SwiftUI
import SwiftData

struct AlarmCenterView: View {
    @StateObject private var viewModel: AlarmCenterViewModel
    @State private var selectedAlarm: AlarmSchedule?
    @State private var showSession = false
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        _viewModel = StateObject(wrappedValue: AlarmCenterViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                quickActions

                List(viewModel.activeAlarms, id: \.id) { alarm in
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(alarm.label)
                                .foregroundStyle(.white)
                            Text("\(alarm.alarmKindRaw) - \(alarm.currentStateRaw)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(alarm.scheduledAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(AppTheme.info)
                        }

                        Button("Run alarm session") {
                            selectedAlarm = alarm
                            showSession = true
                        }
                        .buttonStyle(SurvivalButtonStyle(color: AppTheme.info))
                    }
                    .listRowBackground(AppTheme.card)
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
            }
            .padding(.horizontal, 12)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Alarm Center")
        }
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showSession, onDismiss: {
            selectedAlarm = nil
            viewModel.refresh()
        }) {
            if let selectedAlarm {
                ActiveAlarmSessionView(context: context, alarm: selectedAlarm)
            } else {
                Text("No alarm selected")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.createAlarm(
                    kind: .wakeForWork,
                    label: "Work wake-up",
                    fireAt: Date().addingTimeInterval(5 * 60)
                )
            } label: {
                Text("Create Work Alarm (Strict)")
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.largeButtonHeight)
            }
            .buttonStyle(SurvivalButtonStyle(color: AppTheme.critical))

            Button {
                viewModel.createAlarm(
                    kind: .wakeForClass,
                    label: "Class wake-up",
                    fireAt: Date().addingTimeInterval(7 * 60)
                )
            } label: {
                Text("Create Class Alarm")
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.largeButtonHeight)
            }
            .buttonStyle(SurvivalButtonStyle(color: AppTheme.warning))
        }
        .padding(.top, 8)
    }
}

struct SurvivalButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}
