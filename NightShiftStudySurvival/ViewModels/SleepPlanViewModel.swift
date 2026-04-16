import Foundation
import SwiftData

@MainActor
final class SleepPlanViewModel: ObservableObject {
    @Published private(set) var todayRecommendation: SleepRecommendation?
    @Published private(set) var latestBlockStatuses: [UUID: SleepExecutionStatus] = [:]

    private let context: ModelContext
    private let engine = SleepRecommendationEngine()

    init(context: ModelContext) {
        self.context = context
    }

    func generateToday() {
        guard let settings = fetchSettings() else { return }

        let weekday = mappedWeekday(from: .now)
        let todaySessions = fetchSessions(day: weekday)
        let tomorrowSessions = fetchSessions(day: weekday == 7 ? 1 : weekday + 1)

        let request = SleepRecommendationRequest(
            now: .now,
            sessionsToday: todaySessions,
            sessionsTomorrow: tomorrowSessions,
            settings: settings,
            sleepFollowRate: currentSleepFollowRate(),
            recentMissedAlarms: recentMissedAlarmCount()
        )

        let result = engine.generate(for: request)

        let recommendation = SleepRecommendation(date: .now, dayType: result.dayType, note: result.note)
        for block in result.blocks {
            block.recommendation = recommendation
            recommendation.blocks.append(block)
            context.insert(block)
        }

        context.insert(recommendation)
        try? context.save()

        todayRecommendation = recommendation
        loadLatestStatuses(for: recommendation)
    }

    func markBlock(_ block: SleepBlock, status: SleepExecutionStatus) {
        let log = SleepExecutionLog(
            blockId: block.id,
            strategyLabel: block.strategyLabelRaw,
            plannedStart: block.startAt,
            plannedEnd: block.endAt,
            status: status
        )

        context.insert(log)
        try? context.save()

        latestBlockStatuses[block.id] = status
    }

    private func fetchSettings() -> AppSettings? {
        let descriptor = FetchDescriptor<AppSettings>()
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchSessions(day: Int) -> [ClassSession] {
        let descriptor = FetchDescriptor<ClassSession>(
            predicate: #Predicate { $0.dayOfWeek == day && $0.isTemporarilyDisabled == false },
            sortBy: [SortDescriptor(\.startMinutes)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func mappedWeekday(from date: Date) -> Int {
        let systemDay = Calendar.current.component(.weekday, from: date)
        switch systemDay {
        case 1: return 7
        case 2: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        case 6: return 5
        case 7: return 6
        default: return 1
        }
    }

    private func loadLatestStatuses(for recommendation: SleepRecommendation) {
        let descriptor = FetchDescriptor<SleepExecutionLog>(sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        let logs = (try? context.fetch(descriptor)) ?? []

        var map: [UUID: SleepExecutionStatus] = [:]
        for block in recommendation.blocks {
            if let latest = logs.first(where: { $0.blockId == block.id }) {
                map[block.id] = latest.status
            }
        }
        latestBlockStatuses = map
    }

    private func currentSleepFollowRate() -> Double {
        let descriptor = FetchDescriptor<SleepExecutionLog>(sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        let logs = (try? context.fetch(descriptor)) ?? []
        guard !logs.isEmpty else { return 0.6 }

        let recent = Array(logs.prefix(12))
        let followed = recent.filter { $0.status == .followed }.count
        return Double(followed) / Double(recent.count)
    }

    private func recentMissedAlarmCount() -> Int {
        let descriptor = FetchDescriptor<AlarmSchedule>(sortBy: [SortDescriptor(\.scheduledAt, order: .reverse)])
        let alarms = (try? context.fetch(descriptor)) ?? []
        return Array(alarms.prefix(12)).filter(\.isFailed).count
    }
}
