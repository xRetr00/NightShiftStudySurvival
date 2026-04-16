import Foundation
import SwiftData

struct ImportSelection {
    var settings: Bool = true
    var timetable: Bool = true
    var alarms: Bool = true
    var sleepPlans: Bool = true
    var sleepLogs: Bool = true

    static let all = ImportSelection()
}

struct ImportPreview {
    let incomingSettings: Int
    let incomingSubjects: Int
    let incomingSessions: Int
    let incomingAlarms: Int
    let incomingSleepRecommendations: Int
    let incomingSleepLogs: Int

    let existingSettings: Int
    let existingSubjects: Int
    let existingSessions: Int
    let existingAlarms: Int
    let existingSleepRecommendations: Int
    let existingSleepLogs: Int

    let warnings: [String]

    var summary: String {
        "Incoming: \(incomingSubjects) subjects / \(incomingSessions) sessions / \(incomingAlarms) alarms / \(incomingSleepRecommendations) sleep plans / \(incomingSleepLogs) sleep logs. Existing data will be replaced only for selected sections."
    }
}

@MainActor
enum DataImportService {
    private struct ImportSnapshot: Codable {
        let settings: ImportSettings?
        let subjects: [ImportSubject]
        let alarms: [ImportAlarm]
        let sleepRecommendations: [ImportSleepRecommendation]
        let sleepExecutionLogs: [ImportSleepExecutionLog]
    }

    private struct ImportSettings: Codable {
        let workStartMinutes: Int
        let workEndMinutes: Int
        let homeToUniversityTravelMinutes: Int
        let workToHomeTravelMinutes: Int
        let homeToWorkTravelMinutes: Int
        let mathDifficulty: String
        let alarmSoundStyle: String?
        let alarmLoudnessProfile: String?
        let requiredCorrectMathAnswers: Int
        let recoveryBoostMinutes: Int
        let maxMissedAlarmRetries: Int
    }

    private struct ImportSubject: Codable {
        let code: String
        let title: String
        let attendanceMode: String
        let isEnabled: Bool
        let isOnline: Bool
        let importance: Int
        let colorHex: String
        let notes: String
        let sessions: [ImportSession]
    }

    private struct ImportSession: Codable {
        let dayOfWeek: Int
        let startMinutes: Int
        let endMinutes: Int
        let hasConflict: Bool
        let isTemporarilyDisabled: Bool
        let isPractical: Bool
    }

    private struct ImportAlarm: Codable {
        let label: String
        let kind: String
        let currentState: String
        let scheduledAt: String
        let isCompleted: Bool
        let isFailed: Bool
        let overrideUsed: Bool
        let transitions: Int
    }

    private struct ImportSleepRecommendation: Codable {
        let date: String
        let dayType: String
        let note: String
        let isUserEdited: Bool
        let blocks: [ImportSleepBlock]
    }

    private struct ImportSleepBlock: Codable {
        let startAt: String
        let endAt: String
        let strategyLabel: String
        let isLocked: Bool
    }

    private struct ImportSleepExecutionLog: Codable {
        let loggedAt: String
        let blockId: String?
        let strategyLabel: String
        let plannedStart: String?
        let plannedEnd: String?
        let status: String
        let note: String
    }

    static func validateJSON(_ raw: String) -> String? {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Validation failed: JSON is empty."
        }

        guard decodeSnapshot(raw) != nil else {
            return "Validation failed: unsupported JSON shape."
        }

        return nil
    }

    static func previewJSON(_ raw: String, context: ModelContext) -> ImportPreview? {
        guard let snapshot = decodeSnapshot(raw) else { return nil }

        let incomingSubjects = snapshot.subjects.count
        let incomingSessions = snapshot.subjects.flatMap(\.sessions).count
        let incomingAlarms = snapshot.alarms.count
        let incomingRecommendations = snapshot.sleepRecommendations.count
        let incomingSleepLogs = snapshot.sleepExecutionLogs.count

        let existingSubjects = (try? context.fetch(FetchDescriptor<Subject>()))?.count ?? 0
        let existingSessions = (try? context.fetch(FetchDescriptor<ClassSession>()))?.count ?? 0
        let existingAlarms = (try? context.fetch(FetchDescriptor<AlarmSchedule>()))?.count ?? 0
        let existingRecommendations = (try? context.fetch(FetchDescriptor<SleepRecommendation>()))?.count ?? 0
        let existingSleepLogs = (try? context.fetch(FetchDescriptor<SleepExecutionLog>()))?.count ?? 0
        let existingSettings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.count ?? 0

        var warnings: [String] = []
        if snapshot.settings == nil {
            warnings.append("Backup has no settings section.")
        }
        if incomingSubjects == 0 {
            warnings.append("Backup has no timetable data.")
        }
        if incomingRecommendations == 0 && incomingSleepLogs == 0 {
            warnings.append("Backup has no sleep analytics data.")
        }

        return ImportPreview(
            incomingSettings: snapshot.settings == nil ? 0 : 1,
            incomingSubjects: incomingSubjects,
            incomingSessions: incomingSessions,
            incomingAlarms: incomingAlarms,
            incomingSleepRecommendations: incomingRecommendations,
            incomingSleepLogs: incomingSleepLogs,
            existingSettings: existingSettings,
            existingSubjects: existingSubjects,
            existingSessions: existingSessions,
            existingAlarms: existingAlarms,
            existingSleepRecommendations: existingRecommendations,
            existingSleepLogs: existingSleepLogs,
            warnings: warnings
        )
    }

    static func importJSON(
        _ raw: String,
        context: ModelContext,
        selection: ImportSelection = .all,
        wipeSelectedSections: Bool = true
    ) -> String {
        guard let snapshot = decodeSnapshot(raw) else {
            return "Import failed: unsupported JSON shape."
        }

        if wipeSelectedSections {
            clearSelectedSections(context: context, selection: selection)
        }

        let iso = ISO8601DateFormatter()

        if selection.settings, let importedSettings = snapshot.settings {
            let settings = AppSettings(
                workStartMinutes: importedSettings.workStartMinutes,
                workEndMinutes: importedSettings.workEndMinutes,
                workToHomeTravelMinutes: importedSettings.workToHomeTravelMinutes,
                homeToUniversityTravelMinutes: importedSettings.homeToUniversityTravelMinutes,
                homeToWorkTravelMinutes: importedSettings.homeToWorkTravelMinutes,
                mathDifficulty: importedSettings.mathDifficulty,
                alarmSoundStyle: importedSettings.alarmSoundStyle ?? "Default",
                alarmLoudnessProfile: importedSettings.alarmLoudnessProfile ?? "High",
                requiredCorrectMathAnswers: importedSettings.requiredCorrectMathAnswers,
                recoveryBoostMinutes: importedSettings.recoveryBoostMinutes,
                maxMissedAlarmRetries: importedSettings.maxMissedAlarmRetries
            )
            context.insert(settings)
        }

        if selection.timetable {
            for subjectData in snapshot.subjects {
                let subject = Subject(
                    code: subjectData.code,
                    title: subjectData.title,
                    attendanceMode: AttendanceMode(rawValue: subjectData.attendanceMode) ?? .normal,
                    colorHex: subjectData.colorHex,
                    isEnabled: subjectData.isEnabled,
                    isOnline: subjectData.isOnline,
                    importance: subjectData.importance,
                    notes: subjectData.notes
                )
                context.insert(subject)

                for sessionData in subjectData.sessions {
                    let session = ClassSession(
                        dayOfWeek: min(7, max(1, sessionData.dayOfWeek)),
                        startMinutes: min(1439, max(0, sessionData.startMinutes)),
                        endMinutes: min(1439, max(0, sessionData.endMinutes)),
                        location: subject.isOnline ? "Online" : "Campus",
                        isTemporarilyDisabled: sessionData.isTemporarilyDisabled,
                        hasConflict: sessionData.hasConflict,
                        isPractical: sessionData.isPractical,
                        subject: subject
                    )
                    subject.sessions.append(session)
                    context.insert(session)
                }
            }
        }

        if selection.alarms {
            for alarmData in snapshot.alarms {
                let scheduled = iso.date(from: alarmData.scheduledAt) ?? .now
                let alarm = AlarmSchedule(
                    label: alarmData.label,
                    alarmKind: AlarmKind(rawValue: alarmData.kind) ?? .wakeForClass,
                    currentState: AlarmState(rawValue: alarmData.currentState) ?? .preAlarm,
                    scheduledAt: scheduled,
                    enteredCurrentStateAt: scheduled,
                    isCompleted: alarmData.isCompleted,
                    isFailed: alarmData.isFailed,
                    overrideUsed: alarmData.overrideUsed
                )
                context.insert(alarm)
            }
        }

        if selection.sleepPlans {
            for recommendationData in snapshot.sleepRecommendations {
                let date = iso.date(from: recommendationData.date) ?? .now
                let recommendation = SleepRecommendation(
                    date: date,
                    dayType: DayType(rawValue: recommendationData.dayType) ?? .recovery,
                    note: recommendationData.note,
                    isUserEdited: recommendationData.isUserEdited
                )
                context.insert(recommendation)

                for blockData in recommendationData.blocks {
                    let block = SleepBlock(
                        startAt: iso.date(from: blockData.startAt) ?? .now,
                        endAt: iso.date(from: blockData.endAt) ?? .now,
                        strategyLabel: SleepStrategyLabel(rawValue: blockData.strategyLabel) ?? .mainRecoverySleep,
                        isLocked: blockData.isLocked,
                        recommendation: recommendation
                    )
                    recommendation.blocks.append(block)
                    context.insert(block)
                }
            }
        }

        if selection.sleepLogs {
            for sleepLogData in snapshot.sleepExecutionLogs {
                let blockId = UUID(uuidString: sleepLogData.blockId ?? "") ?? UUID()
                let plannedStart = iso.date(from: sleepLogData.plannedStart ?? "") ?? .now
                let plannedEnd = iso.date(from: sleepLogData.plannedEnd ?? "") ?? .now

                let log = SleepExecutionLog(
                    loggedAt: iso.date(from: sleepLogData.loggedAt) ?? .now,
                    blockId: blockId,
                    strategyLabel: sleepLogData.strategyLabel,
                    plannedStart: plannedStart,
                    plannedEnd: plannedEnd,
                    status: SleepExecutionStatus(rawValue: sleepLogData.status) ?? .ignored,
                    note: sleepLogData.note
                )
                context.insert(log)
            }
        }

        try? context.save()

        return "Import complete. Applied sections: settings=\(selection.settings), timetable=\(selection.timetable), alarms=\(selection.alarms), sleepPlans=\(selection.sleepPlans), sleepLogs=\(selection.sleepLogs)."
    }

    private static func decodeSnapshot(_ raw: String) -> ImportSnapshot? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ImportSnapshot.self, from: data)
    }

    private static func clearSelectedSections(context: ModelContext, selection: ImportSelection) {
        if selection.alarms {
            let transitions = (try? context.fetch(FetchDescriptor<AlarmTransitionLog>())) ?? []
            let alarms = (try? context.fetch(FetchDescriptor<AlarmSchedule>())) ?? []
            for item in transitions { context.delete(item) }
            for item in alarms { context.delete(item) }
        }

        if selection.sleepLogs {
            let sleepLogs = (try? context.fetch(FetchDescriptor<SleepExecutionLog>())) ?? []
            for item in sleepLogs { context.delete(item) }
        }

        if selection.sleepPlans {
            let blocks = (try? context.fetch(FetchDescriptor<SleepBlock>())) ?? []
            let recs = (try? context.fetch(FetchDescriptor<SleepRecommendation>())) ?? []
            for item in blocks { context.delete(item) }
            for item in recs { context.delete(item) }
        }

        if selection.timetable {
            let sessions = (try? context.fetch(FetchDescriptor<ClassSession>())) ?? []
            let subjects = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
            for item in sessions { context.delete(item) }
            for item in subjects { context.delete(item) }
        }

        if selection.settings {
            let settings = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
            for item in settings { context.delete(item) }
        }

        try? context.save()
    }
}
