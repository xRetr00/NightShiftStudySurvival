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
    let incomingSleepBlocks: Int
    let incomingSleepLogs: Int

    let existingSettings: Int
    let existingSubjects: Int
    let existingSessions: Int
    let existingAlarms: Int
    let existingSleepRecommendations: Int
    let existingSleepBlocks: Int
    let existingSleepLogs: Int

    let blockPreview: [String]
    let conflictWarnings: [String]
    let warnings: [String]

    var summary: String {
        "Incoming: \(incomingSubjects) subjects / \(incomingSessions) sessions / \(incomingAlarms) alarms / \(incomingSleepRecommendations) sleep plans / \(incomingSleepBlocks) blocks / \(incomingSleepLogs) sleep logs. Existing data will be replaced only for selected sections."
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
        let iso = ISO8601DateFormatter()

        let incomingSubjects = snapshot.subjects.count
        let incomingSessions = snapshot.subjects.flatMap(\.sessions).count
        let incomingAlarms = snapshot.alarms.count
        let incomingRecommendations = snapshot.sleepRecommendations.count
        let incomingBlocks = snapshot.sleepRecommendations.flatMap(\.blocks).count
        let incomingSleepLogs = snapshot.sleepExecutionLogs.count

        let existingSubjectItems = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        let existingSessionItems = (try? context.fetch(FetchDescriptor<ClassSession>())) ?? []
        let existingAlarmItems = (try? context.fetch(FetchDescriptor<AlarmSchedule>())) ?? []
        let existingRecommendationItems = (try? context.fetch(FetchDescriptor<SleepRecommendation>())) ?? []
        let existingSleepBlockItems = (try? context.fetch(FetchDescriptor<SleepBlock>())) ?? []
        let existingSleepLogItems = (try? context.fetch(FetchDescriptor<SleepExecutionLog>())) ?? []
        let existingSettingsItems = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []

        let existingSubjects = existingSubjectItems.count
        let existingSessions = existingSessionItems.count
        let existingAlarms = existingAlarmItems.count
        let existingRecommendations = existingRecommendationItems.count
        let existingSleepBlocks = existingSleepBlockItems.count
        let existingSleepLogs = existingSleepLogItems.count
        let existingSettings = existingSettingsItems.count

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

        let blockPreview = buildBlockPreview(from: snapshot, iso: iso)
        let conflictWarnings = collectConflictWarnings(
            snapshot: snapshot,
            iso: iso,
            existingSessions: existingSessionItems,
            existingBlocks: existingSleepBlockItems
        )

        return ImportPreview(
            incomingSettings: snapshot.settings == nil ? 0 : 1,
            incomingSubjects: incomingSubjects,
            incomingSessions: incomingSessions,
            incomingAlarms: incomingAlarms,
            incomingSleepRecommendations: incomingRecommendations,
            incomingSleepBlocks: incomingBlocks,
            incomingSleepLogs: incomingSleepLogs,
            existingSettings: existingSettings,
            existingSubjects: existingSubjects,
            existingSessions: existingSessions,
            existingAlarms: existingAlarms,
            existingSleepRecommendations: existingRecommendations,
            existingSleepBlocks: existingSleepBlocks,
            existingSleepLogs: existingSleepLogs,
            blockPreview: blockPreview,
            conflictWarnings: conflictWarnings,
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

    private static func buildBlockPreview(from snapshot: ImportSnapshot, iso: ISO8601DateFormatter) -> [String] {
        var lines: [String] = []
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "MMM d HH:mm"

        for recommendation in snapshot.sleepRecommendations {
            for block in recommendation.blocks {
                guard let start = iso.date(from: block.startAt),
                      let end = iso.date(from: block.endAt) else {
                    continue
                }

                lines.append("\(recommendation.dayType): \(outFormatter.string(from: start)) - \(outFormatter.string(from: end)) [\(block.strategyLabel)]")
                if lines.count >= 6 {
                    return lines
                }
            }
        }

        return lines
    }

    private static func collectConflictWarnings(
        snapshot: ImportSnapshot,
        iso: ISO8601DateFormatter,
        existingSessions: [ClassSession],
        existingBlocks: [SleepBlock]
    ) -> [String] {
        var warnings: [String] = []

        let incomingSessionTuples = snapshot.subjects.flatMap { subject in
            subject.sessions.map { session in
                (
                    subject: subject.code,
                    day: min(7, max(1, session.dayOfWeek)),
                    start: min(1439, max(0, session.startMinutes)),
                    end: min(1439, max(0, session.endMinutes))
                )
            }
        }

        let groupedIncoming = Dictionary(grouping: incomingSessionTuples, by: { $0.day })
        var incomingOverlapCount = 0
        for sessions in groupedIncoming.values {
            let sorted = sessions.sorted { $0.start < $1.start }
            for index in 0..<max(0, sorted.count - 1) {
                if sorted[index + 1].start < sorted[index].end {
                    incomingOverlapCount += 1
                }
            }
        }
        if incomingOverlapCount > 0 {
            warnings.append("Incoming timetable contains \(incomingOverlapCount) overlapping session pair(s).")
        }

        var overlapWithExistingTimetable = 0
        for incoming in incomingSessionTuples {
            if existingSessions.contains(where: {
                $0.dayOfWeek == incoming.day && incoming.start < $0.endMinutes && incoming.end > $0.startMinutes
            }) {
                overlapWithExistingTimetable += 1
            }
        }
        if overlapWithExistingTimetable > 0 {
            warnings.append("Incoming timetable overlaps existing sessions in \(overlapWithExistingTimetable) slot(s).")
        }

        let incomingSleepRanges = snapshot.sleepRecommendations.flatMap { rec in
            rec.blocks.compactMap { block -> (Date, Date)? in
                guard let start = iso.date(from: block.startAt), let end = iso.date(from: block.endAt) else {
                    return nil
                }
                return (start, end)
            }
        }

        var overlapWithExistingSleep = 0
        for range in incomingSleepRanges {
            if existingBlocks.contains(where: { range.0 < $0.endAt && range.1 > $0.startAt }) {
                overlapWithExistingSleep += 1
            }
        }
        if overlapWithExistingSleep > 0 {
            warnings.append("Incoming sleep blocks overlap existing saved blocks in \(overlapWithExistingSleep) case(s).")
        }

        let sortedIncomingRanges = incomingSleepRanges.sorted(by: { $0.0 < $1.0 })
        var incomingSleepOverlapCount = 0
        for index in 0..<max(0, sortedIncomingRanges.count - 1) {
            if sortedIncomingRanges[index + 1].0 < sortedIncomingRanges[index].1 {
                incomingSleepOverlapCount += 1
            }
        }
        if incomingSleepOverlapCount > 0 {
            warnings.append("Incoming sleep plan includes \(incomingSleepOverlapCount) overlapping block pair(s).")
        }

        return warnings
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
