import Foundation

struct RecoveryContext {
    let dayType: DayType
    let tomorrowDayType: DayType
    let sleepFollowRate: Double
    let recentMissedAlarms: Int
    let recoveryBoostMinutes: Int
}

struct RecoveryAdjustment {
    let reducePlanComplexity: Bool
    let addPreWorkReset: Bool
    let mainSleepExtensionMinutes: Int
    let adviseEarlySleep: Bool
    let summary: String
}

struct RecoveryOptimizationEngine {
    func adjust(for context: RecoveryContext) -> RecoveryAdjustment {
        let reducePlanComplexity = context.sleepFollowRate < 0.45
        let addPreWorkReset = context.recentMissedAlarms >= 2 || context.dayType == .heavy
        let extensionBase = max(0, context.recoveryBoostMinutes)

        let extraFromLoad: Int
        if context.dayType == .recovery {
            extraFromLoad = 40
        } else if context.dayType == .heavy {
            extraFromLoad = 25
        } else {
            extraFromLoad = 10
        }

        let tomorrowPenalty = context.tomorrowDayType == .heavy ? 20 : 0
        let mainSleepExtensionMinutes = extensionBase + extraFromLoad + tomorrowPenalty
        let adviseEarlySleep = context.tomorrowDayType == .heavy || context.recentMissedAlarms >= 2

        let summary: String
        if reducePlanComplexity {
            summary = "Recovery logic simplified because recent blocks were frequently ignored."
        } else if adviseEarlySleep {
            summary = "Tomorrow load is high; prioritize earlier main sleep."
        } else {
            summary = "Recovery logic stable; keep consistent sleep anchors."
        }

        return RecoveryAdjustment(
            reducePlanComplexity: reducePlanComplexity,
            addPreWorkReset: addPreWorkReset,
            mainSleepExtensionMinutes: mainSleepExtensionMinutes,
            adviseEarlySleep: adviseEarlySleep,
            summary: summary
        )
    }
}
