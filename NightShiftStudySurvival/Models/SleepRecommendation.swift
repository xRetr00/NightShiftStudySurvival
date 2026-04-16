import Foundation
import SwiftData

@Model
final class SleepRecommendation {
    var id: UUID
    var date: Date
    var dayTypeRaw: String
    var note: String
    var isUserEdited: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SleepBlock.recommendation)
    var blocks: [SleepBlock]

    init(
        id: UUID = UUID(),
        date: Date,
        dayType: DayType,
        note: String = "",
        isUserEdited: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        blocks: [SleepBlock] = []
    ) {
        self.id = id
        self.date = date
        self.dayTypeRaw = dayType.rawValue
        self.note = note
        self.isUserEdited = isUserEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks
    }

    var dayType: DayType {
        get { DayType(rawValue: dayTypeRaw) ?? .recovery }
        set {
            dayTypeRaw = newValue.rawValue
            updatedAt = .now
        }
    }
}

@Model
final class SleepBlock {
    var id: UUID
    var startAt: Date
    var endAt: Date
    var strategyLabelRaw: String
    var isLocked: Bool

    var recommendation: SleepRecommendation?

    init(
        id: UUID = UUID(),
        startAt: Date,
        endAt: Date,
        strategyLabel: SleepStrategyLabel,
        isLocked: Bool = false,
        recommendation: SleepRecommendation? = nil
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.strategyLabelRaw = strategyLabel.rawValue
        self.isLocked = isLocked
        self.recommendation = recommendation
    }

    var strategyLabel: SleepStrategyLabel {
        get { SleepStrategyLabel(rawValue: strategyLabelRaw) ?? .mainRecoverySleep }
        set { strategyLabelRaw = newValue.rawValue }
    }
}
