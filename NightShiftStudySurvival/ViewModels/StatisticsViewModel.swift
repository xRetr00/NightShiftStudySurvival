import Foundation
import SwiftData

struct ReliabilityInsight: Identifiable {
    let id = UUID()
    let text: String
}

struct WeekdayTrend: Identifiable {
    let id = UUID()
    let weekday: String
    let completionRate: Double
    let missedCount: Int
}

struct SleepHistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let dateLabel: String
    let followRate: Double
    let followedCount: Int
    let totalCount: Int
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var transitionCount = 0
    @Published private(set) var completionRate = 0.0
    @Published private(set) var missedCount = 0
    @Published private(set) var escalationRate = 0.0
    @Published private(set) var avgDriftMillis = 0
    @Published private(set) var sleepFollowRate = 0.0
    @Published private(set) var weekdayTrends: [WeekdayTrend] = []
    @Published private(set) var sleepHistory: [SleepHistoryPoint] = []
    @Published private(set) var insights: [ReliabilityInsight] = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func refresh() {
        let transitionDescriptor = FetchDescriptor<AlarmTransitionLog>()
        let alarmDescriptor = FetchDescriptor<AlarmSchedule>()
        let sleepDescriptor = FetchDescriptor<SleepExecutionLog>()

        let transitions = (try? context.fetch(transitionDescriptor)) ?? []
        let alarms = (try? context.fetch(alarmDescriptor)) ?? []
        let sleepLogs = (try? context.fetch(sleepDescriptor)) ?? []

        transitionCount = transitions.count
        let completed = alarms.filter(\.isCompleted).count
        completionRate = alarms.isEmpty ? 0 : Double(completed) / Double(alarms.count)
        missedCount = alarms.filter(\.isFailed).count

        let escalations = transitions.filter { log in
            guard let to = AlarmState(rawValue: log.toStateRaw) else { return false }
            return to == .escalation1 || to == .escalation2 || to == .emergency
        }.count

        escalationRate = transitions.isEmpty ? 0 : Double(escalations) / Double(transitions.count)

        if !transitions.isEmpty {
            avgDriftMillis = transitions.map(\.driftMillis).reduce(0, +) / transitions.count
        } else {
            avgDriftMillis = 0
        }

        let followed = sleepLogs.filter { $0.status == .followed }.count
        sleepFollowRate = sleepLogs.isEmpty ? 0 : Double(followed) / Double(sleepLogs.count)

        weekdayTrends = buildWeekdayTrends(alarms: alarms)
        sleepHistory = buildSleepHistory(logs: sleepLogs)

        buildInsights(alarms: alarms, transitions: transitions, sleepLogs: sleepLogs)
    }

    private func buildInsights(alarms: [AlarmSchedule], transitions: [AlarmTransitionLog], sleepLogs: [SleepExecutionLog]) {
        var lines: [ReliabilityInsight] = []

        let mondayFailures = alarms.filter { alarm in
            Calendar.current.component(.weekday, from: alarm.scheduledAt) == 2 && alarm.isFailed
        }.count
        if mondayFailures > 0 {
            lines.append(ReliabilityInsight(text: "You usually miss early wake-ups on Monday."))
        }

        let thursdaySuccess = alarms.filter {
            Calendar.current.component(.weekday, from: $0.scheduledAt) == 5 && $0.isCompleted
        }.count
        if thursdaySuccess > 0 {
            lines.append(ReliabilityInsight(text: "Thursday is your most stable alarm day."))
        }

        let overrides = transitions.filter(\.overrideUsed).count
        if overrides > 1 {
            lines.append(ReliabilityInsight(text: "Work alarms are using emergency override too often. Increase difficulty."))
        }

        if completionRate >= 0.85 {
            lines.append(ReliabilityInsight(text: "High completion rate this week. Keep pre-work reset consistent."))
        }

        if sleepFollowRate < 0.5, sleepLogs.count >= 4 {
            lines.append(ReliabilityInsight(text: "Sleep blocks are often ignored. Reduce plan complexity and lock one main recovery block."))
        }

        if sleepFollowRate >= 0.7, sleepLogs.count >= 4 {
            lines.append(ReliabilityInsight(text: "You perform better when sticking to generated recovery blocks."))
        }

        let mainSleepLogs = sleepLogs.filter { $0.strategyLabel == SleepStrategyLabel.mainRecoverySleep.rawValue }
        if !mainSleepLogs.isEmpty {
            let before4PM = mainSleepLogs.filter {
                Calendar.current.component(.hour, from: $0.plannedStart) < 16 && $0.status == .followed
            }.count
            if before4PM * 2 >= max(1, mainSleepLogs.count) {
                lines.append(ReliabilityInsight(text: "You perform better when your main sleep starts before 4 PM."))
            }
        }

        if let worst = weekdayTrends.max(by: { $0.missedCount < $1.missedCount }), worst.missedCount > 0 {
            lines.append(ReliabilityInsight(text: "\(worst.weekday) is currently the weakest alarm day. Add an earlier pre-alarm."))
        }

        if lines.isEmpty {
            lines.append(ReliabilityInsight(text: "Not enough data yet. Keep using alarms for 3-5 days to unlock insights."))
        }

        insights = lines
    }

    private func buildWeekdayTrends(alarms: [AlarmSchedule]) -> [WeekdayTrend] {
        let grouped = Dictionary(grouping: alarms) { weekdayLabel(from: $0.scheduledAt) }
        let ordered = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        return ordered.compactMap { key in
            guard let dayAlarms = grouped[key], !dayAlarms.isEmpty else { return nil }
            let completed = dayAlarms.filter(\.isCompleted).count
            let missed = dayAlarms.filter(\.isFailed).count
            let rate = Double(completed) / Double(dayAlarms.count)
            return WeekdayTrend(weekday: key, completionRate: rate, missedCount: missed)
        }
    }

    private func weekdayLabel(from date: Date) -> String {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "-"
        }
    }

    private func buildSleepHistory(logs: [SleepExecutionLog]) -> [SleepHistoryPoint] {
        guard !logs.isEmpty else { return [] }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.loggedAt) }

        let sortedDays = grouped.keys.sorted()
        let recentDays = Array(sortedDays.suffix(21))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return recentDays.compactMap { day in
            guard let dayLogs = grouped[day], !dayLogs.isEmpty else { return nil }
            let followed = dayLogs.filter { $0.status == .followed }.count
            let total = dayLogs.count
            let rate = Double(followed) / Double(total)

            return SleepHistoryPoint(
                date: day,
                dateLabel: formatter.string(from: day),
                followRate: rate,
                followedCount: followed,
                totalCount: total
            )
        }
    }
}
