import SwiftUI
import SwiftData

struct SleepPlanView: View {
    @StateObject private var viewModel: SleepPlanViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: SleepPlanViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button {
                    viewModel.generateToday()
                } label: {
                    Text("Generate Today Sleep Plan")
                        .frame(maxWidth: .infinity)
                        .frame(height: AppTheme.largeButtonHeight)
                }
                .buttonStyle(SurvivalButtonStyle(color: AppTheme.info))

                if let recommendation = viewModel.todayRecommendation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.dayTypeRaw)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(recommendation.note)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))

                    List(recommendation.blocks, id: \.id) { block in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(block.strategyLabelRaw)
                                .foregroundStyle(.white)
                            Text("\(block.startAt, style: .time) -> \(block.endAt, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))

                            if let status = viewModel.latestBlockStatuses[block.id] {
                                Text("Status: \(status.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(status == .followed ? AppTheme.safe : AppTheme.warning)
                            }

                            HStack {
                                Button("Followed") {
                                    viewModel.markBlock(block, status: .followed)
                                }
                                .buttonStyle(.bordered)

                                Button("Ignored") {
                                    viewModel.markBlock(block, status: .ignored)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .listRowBackground(AppTheme.card)
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                } else {
                    Spacer()
                    Text("No plan generated yet")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
            }
            .padding(12)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Sleep Plan")
        }
    }
}
