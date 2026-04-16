import Foundation
import SwiftData

@Model
final class SleepExecutionLog {
    var id: UUID
    var loggedAt: Date
    var blockId: UUID
    var strategyLabel: String
    var plannedStart: Date
    var plannedEnd: Date
    var statusRaw: String
    var note: String

    init(
        id: UUID = UUID(),
        loggedAt: Date = .now,
        blockId: UUID,
        strategyLabel: String,
        plannedStart: Date,
        plannedEnd: Date,
        status: SleepExecutionStatus,
        note: String = ""
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.blockId = blockId
        self.strategyLabel = strategyLabel
        self.plannedStart = plannedStart
        self.plannedEnd = plannedEnd
        self.statusRaw = status.rawValue
        self.note = note
    }

    var status: SleepExecutionStatus {
        get { SleepExecutionStatus(rawValue: statusRaw) ?? .followed }
        set { statusRaw = newValue.rawValue }
    }
}
