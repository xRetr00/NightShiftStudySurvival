import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var workStartMinutes: Int
    var workEndMinutes: Int
    var workToHomeTravelMinutes: Int
    var homeToUniversityTravelMinutes: Int
    var homeToWorkTravelMinutes: Int
    var mathDifficulty: String
    var alarmSoundStyle: String
    var alarmLoudnessProfile: String
    var requiredCorrectMathAnswers: Int
    var showDMOnDashboard: Bool
    var autoHideSkippedClasses: Bool
    var preferredDarkMode: Bool
    var highContrastMode: Bool
    var enableStrongHaptics: Bool
    var recoveryBoostMinutes: Int
    var showHeavyDayPrepReminder: Bool
    var autoAdjustMathDifficulty: Bool
    var maxMissedAlarmRetries: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workStartMinutes: Int = 22 * 60,
        workEndMinutes: Int = 5 * 60,
        workToHomeTravelMinutes: Int = 30,
        homeToUniversityTravelMinutes: Int = 45,
        homeToWorkTravelMinutes: Int = 0,
        mathDifficulty: String = "Medium",
        alarmSoundStyle: String = "Default",
        alarmLoudnessProfile: String = "High",
        requiredCorrectMathAnswers: Int = 3,
        showDMOnDashboard: Bool = true,
        autoHideSkippedClasses: Bool = false,
        preferredDarkMode: Bool = true,
        highContrastMode: Bool = false,
        enableStrongHaptics: Bool = true,
        recoveryBoostMinutes: Int = 45,
        showHeavyDayPrepReminder: Bool = true,
        autoAdjustMathDifficulty: Bool = true,
        maxMissedAlarmRetries: Int = 2,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workStartMinutes = workStartMinutes
        self.workEndMinutes = workEndMinutes
        self.workToHomeTravelMinutes = workToHomeTravelMinutes
        self.homeToUniversityTravelMinutes = homeToUniversityTravelMinutes
        self.homeToWorkTravelMinutes = homeToWorkTravelMinutes
        self.mathDifficulty = mathDifficulty
        self.alarmSoundStyle = alarmSoundStyle
        self.alarmLoudnessProfile = alarmLoudnessProfile
        self.requiredCorrectMathAnswers = requiredCorrectMathAnswers
        self.showDMOnDashboard = showDMOnDashboard
        self.autoHideSkippedClasses = autoHideSkippedClasses
        self.preferredDarkMode = preferredDarkMode
        self.highContrastMode = highContrastMode
        self.enableStrongHaptics = enableStrongHaptics
        self.recoveryBoostMinutes = recoveryBoostMinutes
        self.showHeavyDayPrepReminder = showHeavyDayPrepReminder
        self.autoAdjustMathDifficulty = autoAdjustMathDifficulty
        self.maxMissedAlarmRetries = maxMissedAlarmRetries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
