import SwiftUI
import SwiftData
#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: StatisticsViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                metricCard(title: "Transition logs", value: "\(viewModel.transitionCount)", color: AppTheme.info)
                metricCard(title: "Completion rate", value: "\(Int(viewModel.completionRate * 100))%", color: AppTheme.safe)
                metricCard(title: "Missed alarms", value: "\(viewModel.missedCount)", color: AppTheme.critical)
                metricCard(title: "Escalation rate", value: "\(Int(viewModel.escalationRate * 100))%", color: AppTheme.warning)
                metricCard(title: "Avg transition drift", value: "\(viewModel.avgDriftMillis) ms", color: AppTheme.info)
                metricCard(title: "Sleep block follow rate", value: "\(Int(viewModel.sleepFollowRate * 100))%", color: AppTheme.safe)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekday trend")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if viewModel.weekdayTrends.isEmpty {
                        Text("No trend data yet")
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        ForEach(viewModel.weekdayTrends) { trend in
                            HStack {
                                Text(trend.weekday)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(trend.completionRate * 100))% complete")
                                    .foregroundStyle(AppTheme.info)
                                Text("missed: \(trend.missedCount)")
                                    .foregroundStyle(AppTheme.warning)
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))

#if canImport(Charts)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completion chart")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Chart(viewModel.weekdayTrends) { trend in
                        BarMark(
                            x: .value("Day", trend.weekday),
                            y: .value("Completion", Int(trend.completionRate * 100))
                        )
                        .foregroundStyle(AppTheme.info)
                    }
                    .frame(height: 180)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
#endif

                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(viewModel.insights) { insight in
                        Text("- \(insight.text)")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            }
            .padding(12)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Statistics")
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.largeTitle.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}
