import Foundation

struct DayClassificationInput {
    let sessions: [ClassSession]
    let mandatoryCount: Int
    let overlapCount: Int
    let mandatoryMinutes: Int
    let breakFragmentationScore: Int
    let nextDayLoadScore: Int

    init(
        sessions: [ClassSession],
        mandatoryCount: Int,
        overlapCount: Int,
        mandatoryMinutes: Int = 0,
        breakFragmentationScore: Int = 0,
        nextDayLoadScore: Int = 0
    ) {
        self.sessions = sessions
        self.mandatoryCount = mandatoryCount
        self.overlapCount = overlapCount
        self.mandatoryMinutes = mandatoryMinutes
        self.breakFragmentationScore = breakFragmentationScore
        self.nextDayLoadScore = nextDayLoadScore
    }
}

struct DayClassificationEngine {
    func classify(_ input: DayClassificationInput) -> DayType {
        guard !input.sessions.isEmpty else {
            return .recovery
        }

        let totalMinutes = input.sessions.reduce(0) { $0 + $1.durationMinutes }
        let spanMinutes = max(0, (input.sessions.map { $0.endMinutes }.max() ?? 0) - (input.sessions.map { $0.startMinutes }.min() ?? 0))
        let computedFragmentation = fragmentationScore(for: input.sessions)
        let mandatoryPressure = max(input.mandatoryCount, input.mandatoryMinutes / 80)

        var score = 0
        score += min(4, totalMinutes / 90)
        score += min(3, spanMinutes / 180)
        score += min(3, mandatoryPressure)
        score += min(3, input.overlapCount)
        score += min(2, max(input.breakFragmentationScore, computedFragmentation))
        score += min(2, input.nextDayLoadScore)

        if score >= 8 { return .heavy }
        if score >= 5 { return .medium }
        return .light
    }

    private func fragmentationScore(for sessions: [ClassSession]) -> Int {
        let sorted = sessions.sorted { $0.startMinutes < $1.startMinutes }
        guard sorted.count > 1 else { return 0 }

        var fragmentedGaps = 0
        for idx in 0..<(sorted.count - 1) {
            let gap = sorted[idx + 1].startMinutes - sorted[idx].endMinutes
            if gap >= 30 && gap <= 110 {
                fragmentedGaps += 1
            }
        }

        return fragmentedGaps
    }
}
