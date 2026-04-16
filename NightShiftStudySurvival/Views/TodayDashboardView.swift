import SwiftUI
import SwiftData

struct TodayDashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    shiftCard
                    classesCard
                    instructionCard
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("NightShift Study Survival")
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private var headerCard: some View {
        card {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.dayLabel)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(snapshot.dayType.rawValue)
                        .font(.headline)
                        .foregroundStyle(colorForDayType(snapshot.dayType))
                    Text("First class: \(snapshot.firstClass)")
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Last class: \(snapshot.lastClass)")
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Next alarm: \(snapshot.nextAlarm)")
                        .foregroundStyle(AppTheme.info)
                    if let prep = snapshot.prepReminder {
                        Text(prep)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.warning)
                    }
                }
            } else {
                Text("Loading...")
                    .foregroundStyle(.white)
            }
        }
    }

    private var shiftCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Work shift tonight")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("22:00 -> 05:00")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
                Text("Leave home at 22:00")
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var classesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Attendance filter")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let snapshot = viewModel.snapshot {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Must attend (DVZ): \(snapshot.mandatory.count)")
                            .foregroundStyle(AppTheme.critical)
                        Text("Can skip (DM): \(snapshot.optional.count)")
                            .foregroundStyle(AppTheme.safe)
                        if snapshot.mandatory.isEmpty && snapshot.optional.isEmpty {
                            Text("No class today")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }
        }
    }

    private var instructionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick guidance")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.snapshot?.quickInstruction ?? "Sleep now")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.critical)
            }
        }
    }

    private func colorForDayType(_ dayType: DayType) -> Color {
        switch dayType {
        case .heavy:
            return AppTheme.critical
        case .medium:
            return AppTheme.warning
        case .light:
            return AppTheme.info
        case .recovery:
            return AppTheme.safe
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}
