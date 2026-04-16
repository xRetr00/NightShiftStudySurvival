import Foundation
import SwiftData

struct TodaySnapshot {
    let date: Date
    let dayLabel: String
    let dayType: DayType
    let firstClass: String
    let lastClass: String
    let mandatory: [ClassSession]
    let optional: [ClassSession]
    let nextAlarm: String
    let quickInstruction: String
    let prepReminder: String?
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: TodaySnapshot?

    private let context: ModelContext
    private let dayClassifier = DayClassificationEngine()
    private let guidanceEngine = DashboardGuidanceEngine()

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    func refresh(now: Date = .now) {
        let weekday = mappedWeekday(from: now)
        let tomorrow = weekday == 7 ? 1 : weekday + 1
        let settings = fetchSettings()
        let sessions = fetchSessions(for: weekday).filter { !$0.isTemporarilyDisabled && ($0.subject?.isEnabled ?? true) }
        let tomorrowSessions = fetchSessions(for: tomorrow).filter { !$0.isTemporarilyDisabled && ($0.subject?.isEnabled ?? true) }

        let mandatory = sessions.filter { $0.subject?.attendanceMode == .dvz }
        let optional = (settings?.showDMOnDashboard ?? true) ? sessions.filter { $0.subject?.attendanceMode == .dm } : []
        let mandatoryMinutes = mandatory.reduce(0) { $0 + $1.durationMinutes }

        let dayType = dayClassifier.classify(
            DayClassificationInput(
                sessions: sessions,
                mandatoryCount: mandatory.count,
                overlapCount: sessions.filter(\.hasConflict).count,
                mandatoryMinutes: mandatoryMinutes,
                breakFragmentationScore: fragmentedGapScore(for: sessions),
                nextDayLoadScore: 0
            )
        )

        let tomorrowDayType = dayClassifier.classify(
            DayClassificationInput(
                sessions: tomorrowSessions,
                mandatoryCount: tomorrowSessions.filter { $0.subject?.attendanceMode == .dvz }.count,
                overlapCount: tomorrowSessions.filter(\.hasConflict).count,
                mandatoryMinutes: tomorrowSessions.filter { $0.subject?.attendanceMode == .dvz }.reduce(0) { $0 + $1.durationMinutes },
                breakFragmentationScore: fragmentedGapScore(for: tomorrowSessions),
                nextDayLoadScore: 0
            )
        )

        let firstClass = sessions.min(by: { $0.startMinutes < $1.startMinutes })?.startTimeLabel ?? "No class"
        let lastClass = sessions.max(by: { $0.endMinutes < $1.endMinutes })?.endTimeLabel ?? "No class"

        let nextAlarm = fetchNextAlarmLabel(now: now)
        let quickInstruction = guidanceEngine.instruction(for: sessions, mandatory: mandatory, now: now)
        let prepReminder = buildPrepReminder(settings: settings, tomorrowDayType: tomorrowDayType)

        snapshot = TodaySnapshot(
            date: now,
            dayLabel: weekdayLabel(for: weekday),
            dayType: dayType,
            firstClass: firstClass,
            lastClass: lastClass,
            mandatory: mandatory,
            optional: optional,
            nextAlarm: nextAlarm,
            quickInstruction: quickInstruction,
            prepReminder: prepReminder
        )
    }

    private func fetchSessions(for day: Int) -> [ClassSession] {
        let descriptor = FetchDescriptor<ClassSession>(
            predicate: #Predicate { $0.dayOfWeek == day },
            sortBy: [SortDescriptor(\.startMinutes)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchNextAlarmLabel(now: Date) -> String {
        let descriptor = FetchDescriptor<AlarmSchedule>(
            predicate: #Predicate { $0.scheduledAt >= now && $0.isCompleted == false && $0.isFailed == false },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )

        guard let next = (try? context.fetch(descriptor))?.first else {
            return "No alarm"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(next.label) - \(formatter.string(from: next.scheduledAt))"
    }

    private func fragmentedGapScore(for sessions: [ClassSession]) -> Int {
        let sorted = sessions.sorted { $0.startMinutes < $1.startMinutes }
        guard sorted.count > 1 else { return 0 }

        var score = 0
        for idx in 0..<(sorted.count - 1) {
            let gap = sorted[idx + 1].startMinutes - sorted[idx].endMinutes
            if gap >= 30 && gap <= 110 {
                score += 1
            }
        }
        return score
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

    private func weekdayLabel(for day: Int) -> String {
        switch day {
        case 1: return "Monday"
        case 2: return "Tuesday"
        case 3: return "Wednesday"
        case 4: return "Thursday"
        case 5: return "Friday"
        case 6: return "Saturday"
        case 7: return "Sunday"
        default: return "Today"
        }
    }

    private func fetchSettings() -> AppSettings? {
        (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
    }

    private func buildPrepReminder(settings: AppSettings?, tomorrowDayType: DayType) -> String? {
        guard settings?.showHeavyDayPrepReminder ?? true else { return nil }
        guard tomorrowDayType == .heavy else { return nil }
        return "Tomorrow is a heavy day. Sleep earlier tonight."
    }
}
