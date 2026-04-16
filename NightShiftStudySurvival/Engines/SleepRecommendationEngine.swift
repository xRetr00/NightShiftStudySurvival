import Foundation

struct SleepRecommendationRequest {
    let now: Date
    let sessionsToday: [ClassSession]
    let sessionsTomorrow: [ClassSession]
    let settings: AppSettings
    let sleepFollowRate: Double
    let recentMissedAlarms: Int
}

struct SleepRecommendationEngine {
    private let calendar = Calendar.current
    private let dayClassifier = DayClassificationEngine()
    private let recoveryEngine = RecoveryOptimizationEngine()

    func generate(for request: SleepRecommendationRequest) -> (dayType: DayType, blocks: [SleepBlock], note: String) {
        let mandatoryToday = request.sessionsToday.filter { $0.subject?.attendanceMode == .dvz }
        let overlapCount = request.sessionsToday.filter { $0.hasConflict }.count
        let mandatoryMinutes = mandatoryToday.reduce(0) { $0 + $1.durationMinutes }
        let tomorrowMandatoryMinutes = request.sessionsTomorrow
            .filter { $0.subject?.attendanceMode == .dvz }
            .reduce(0) { $0 + $1.durationMinutes }
        let nextDayLoadScore = min(2, tomorrowMandatoryMinutes / 120)

        let tomorrowDayType = dayClassifier.classify(
            DayClassificationInput(
                sessions: request.sessionsTomorrow,
                mandatoryCount: request.sessionsTomorrow.filter { $0.subject?.attendanceMode == .dvz }.count,
                overlapCount: request.sessionsTomorrow.filter { $0.hasConflict }.count,
                mandatoryMinutes: tomorrowMandatoryMinutes,
                breakFragmentationScore: fragmentationScore(in: request.sessionsTomorrow),
                nextDayLoadScore: 0
            )
        )

        let dayType = dayClassifier.classify(
            DayClassificationInput(
                sessions: request.sessionsToday,
                mandatoryCount: mandatoryToday.count,
                overlapCount: overlapCount,
                mandatoryMinutes: mandatoryMinutes,
                breakFragmentationScore: fragmentationScore(in: request.sessionsToday),
                nextDayLoadScore: nextDayLoadScore
            )
        )

        if request.sessionsToday.isEmpty {
            let adjustment = recoveryEngine.adjust(
                for: RecoveryContext(
                    dayType: dayType,
                    tomorrowDayType: tomorrowDayType,
                    sleepFollowRate: request.sleepFollowRate,
                    recentMissedAlarms: request.recentMissedAlarms,
                    recoveryBoostMinutes: request.settings.recoveryBoostMinutes
                )
            )
            let block = recoveryBlock(now: request.now, extensionMinutes: adjustment.mainSleepExtensionMinutes)
            return (dayType, [block], "Recovery day: prioritize long post-shift sleep. \(adjustment.summary)")
        }

        let firstStart = request.sessionsToday.map(\.startMinutes).min() ?? 9 * 60
        let lastMandatoryEnd = mandatoryToday.map(\.endMinutes).max() ?? request.sessionsToday.map(\.endMinutes).max() ?? 16 * 60

        let emergency = emergencyMorningBlock(now: request.now, firstClassStartMinutes: firstStart)
        let adjustment = recoveryEngine.adjust(
            for: RecoveryContext(
                dayType: dayType,
                tomorrowDayType: tomorrowDayType,
                sleepFollowRate: request.sleepFollowRate,
                recentMissedAlarms: request.recentMissedAlarms,
                recoveryBoostMinutes: request.settings.recoveryBoostMinutes
            )
        )

        let main = mainRecoveryBlock(
            now: request.now,
            endMinutes: lastMandatoryEnd,
            extensionMinutes: adjustment.mainSleepExtensionMinutes,
            adviseEarlySleep: adjustment.adviseEarlySleep
        )

        var blocks = [emergency, main]

        if hasMeaningfulMiddayGap(in: request.sessionsToday) && !adjustment.reducePlanComplexity {
            blocks.append(middayResetBlock(now: request.now))
        }

        if adjustment.addPreWorkReset {
            blocks.append(preWorkResetBlock(now: request.now))
        }

        let note: String
        switch dayType {
        case .heavy:
            note = "Heavy survival day: protect mandatory classes, then main recovery sleep."
        case .medium:
            note = "Medium day: short post-shift sleep plus recovery after classes."
        case .light:
            note = "Light day: maintain consistency with one main recovery block."
        case .recovery:
            note = "Recovery day: long recovery sleep and optional prep for tomorrow."
        }

        return (dayType, blocks, "\(note) \(adjustment.summary)")
    }

    private func emergencyMorningBlock(now: Date, firstClassStartMinutes: Int) -> SleepBlock {
        let start = dateToday(atMinutes: 6 * 60, relativeTo: now)
        let wakeTarget = max(7 * 60 + 15, firstClassStartMinutes - 45)
        let end = dateToday(atMinutes: wakeTarget, relativeTo: now)

        return SleepBlock(
            startAt: start,
            endAt: end,
            strategyLabel: .emergencyMorningSleep,
            isLocked: false
        )
    }

    private func mainRecoveryBlock(now: Date, endMinutes: Int, extensionMinutes: Int, adviseEarlySleep: Bool) -> SleepBlock {
        let preferredFloor = adviseEarlySleep ? 15 * 60 + 30 : 16 * 60
        let start = dateToday(atMinutes: max(endMinutes + 45, preferredFloor), relativeTo: now)
        let baseDuration = 180
        let duration = min(360, baseDuration + max(0, extensionMinutes))
        let end = dateToday(atMinutes: min(21 * 60 + 30, startMinutes(from: start) + duration), relativeTo: now)

        return SleepBlock(
            startAt: start,
            endAt: end,
            strategyLabel: .mainRecoverySleep,
            isLocked: false
        )
    }

    private func middayResetBlock(now: Date) -> SleepBlock {
        let start = dateToday(atMinutes: 12 * 60 + 30, relativeTo: now)
        let end = dateToday(atMinutes: 13 * 60 + 20, relativeTo: now)

        return SleepBlock(
            startAt: start,
            endAt: end,
            strategyLabel: .shortPreWorkReset,
            isLocked: false
        )
    }

    private func preWorkResetBlock(now: Date) -> SleepBlock {
        let start = dateToday(atMinutes: 20 * 60 + 10, relativeTo: now)
        let end = dateToday(atMinutes: 20 * 60 + 50, relativeTo: now)

        return SleepBlock(
            startAt: start,
            endAt: end,
            strategyLabel: .shortPreWorkReset,
            isLocked: false
        )
    }

    private func recoveryBlock(now: Date, extensionMinutes: Int) -> SleepBlock {
        let start = dateToday(atMinutes: 7 * 60, relativeTo: now)
        let duration = min(600, 420 + max(0, extensionMinutes))
        let end = dateToday(atMinutes: startMinutes(from: start) + duration, relativeTo: now)

        return SleepBlock(
            startAt: start,
            endAt: end,
            strategyLabel: .recoveryDay,
            isLocked: false
        )
    }

    private func hasMeaningfulMiddayGap(in sessions: [ClassSession]) -> Bool {
        let sorted = sessions.sorted { $0.startMinutes < $1.startMinutes }
        for index in 0..<(sorted.count - 1) {
            let gap = sorted[index + 1].startMinutes - sorted[index].endMinutes
            if gap >= 80 { return true }
        }
        return false
    }

    private func fragmentationScore(in sessions: [ClassSession]) -> Int {
        let sorted = sessions.sorted { $0.startMinutes < $1.startMinutes }
        guard sorted.count > 1 else { return 0 }

        var score = 0
        for index in 0..<(sorted.count - 1) {
            let gap = sorted[index + 1].startMinutes - sorted[index].endMinutes
            if gap >= 30 && gap <= 110 {
                score += 1
            }
        }
        return score
    }

    private func dateToday(atMinutes minutes: Int, relativeTo now: Date) -> Date {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private func startMinutes(from date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
