import Foundation

struct SessionConflict: Identifiable {
    let id = UUID()
    let dayOfWeek: Int
    let overlapStartMinutes: Int
    let overlapEndMinutes: Int
    let sessions: [ClassSession]

    var overlapLabel: String {
        "\(Self.minutesToLabel(overlapStartMinutes)) - \(Self.minutesToLabel(overlapEndMinutes))"
    }

    private static func minutesToLabel(_ minutes: Int) -> String {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

struct ConflictDetectionEngine {
    func detectConflicts(in sessions: [ClassSession]) -> [SessionConflict] {
        let active = sessions
            .filter { !$0.isTemporarilyDisabled }
            .sorted { lhs, rhs in
                if lhs.dayOfWeek == rhs.dayOfWeek {
                    return lhs.startMinutes < rhs.startMinutes
                }
                return lhs.dayOfWeek < rhs.dayOfWeek
            }

        var results: [SessionConflict] = []

        for index in 0..<active.count {
            for nextIndex in (index + 1)..<active.count {
                let first = active[index]
                let second = active[nextIndex]

                if first.dayOfWeek != second.dayOfWeek {
                    break
                }

                let overlapStart = max(first.startMinutes, second.startMinutes)
                let overlapEnd = min(first.endMinutes, second.endMinutes)

                if overlapStart < overlapEnd {
                    results.append(
                        SessionConflict(
                            dayOfWeek: first.dayOfWeek,
                            overlapStartMinutes: overlapStart,
                            overlapEndMinutes: overlapEnd,
                            sessions: [first, second]
                        )
                    )
                }
            }
        }

        return results
    }
}
