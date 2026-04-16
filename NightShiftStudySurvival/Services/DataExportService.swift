import Foundation
import SwiftData

@MainActor
enum DataExportService {
    private struct ExportSnapshot: Codable {
        let exportedAt: String
        let settings: ExportSettings?
        let subjects: [ExportSubject]
        let alarms: [ExportAlarm]
        let sleepRecommendations: [ExportSleepRecommendation]
        let sleepExecutionLogs: [ExportSleepExecutionLog]
    }

    private struct ExportSettings: Codable {
        let workStartMinutes: Int
        let workEndMinutes: Int
        let homeToUniversityTravelMinutes: Int
        let workToHomeTravelMinutes: Int
        let homeToWorkTravelMinutes: Int
        let mathDifficulty: String
        let alarmSoundStyle: String
        let alarmLoudnessProfile: String
        let requiredCorrectMathAnswers: Int
        let recoveryBoostMinutes: Int
        let maxMissedAlarmRetries: Int
    }

    private struct ExportSubject: Codable {
        let code: String
        let title: String
        let attendanceMode: String
        let isEnabled: Bool
        let isOnline: Bool
        let importance: Int
        let colorHex: String
        let notes: String
        let sessions: [ExportSession]
    }

    private struct ExportSession: Codable {
        let dayOfWeek: Int
        let startMinutes: Int
        let endMinutes: Int
        let hasConflict: Bool
        let isTemporarilyDisabled: Bool
        let isPractical: Bool
    }

    private struct ExportAlarm: Codable {
        let id: String
        let label: String
        let kind: String
        let currentState: String
        let scheduledAt: String
        let isCompleted: Bool
        let isFailed: Bool
        let overrideUsed: Bool
        let transitions: Int
    }

    private struct ExportSleepRecommendation: Codable {
        let id: String
        let date: String
        let dayType: String
        let note: String
        let isUserEdited: Bool
        let blocks: [ExportSleepBlock]
    }

    private struct ExportSleepBlock: Codable {
        let id: String
        let startAt: String
        let endAt: String
        let strategyLabel: String
        let isLocked: Bool
    }

    private struct ExportSleepExecutionLog: Codable {
        let loggedAt: String
        let blockId: String
        let strategyLabel: String
        let status: String
        let note: String
    }

    static func exportJSON(context: ModelContext) -> String? {
        let dateFmt = ISO8601DateFormatter()

        let subjects = (try? context.fetch(FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.code)]))) ?? []
        let alarms = (try? context.fetch(FetchDescriptor<AlarmSchedule>(sortBy: [SortDescriptor(\.scheduledAt)]))) ?? []
        let recommendations = (try? context.fetch(FetchDescriptor<SleepRecommendation>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let sleepLogs = (try? context.fetch(FetchDescriptor<SleepExecutionLog>(sortBy: [SortDescriptor(\.loggedAt)]))) ?? []
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first

        let payload = ExportSnapshot(
            exportedAt: dateFmt.string(from: .now),
            settings: settings.map {
                ExportSettings(
                    workStartMinutes: $0.workStartMinutes,
                    workEndMinutes: $0.workEndMinutes,
                    homeToUniversityTravelMinutes: $0.homeToUniversityTravelMinutes,
                    workToHomeTravelMinutes: $0.workToHomeTravelMinutes,
                    homeToWorkTravelMinutes: $0.homeToWorkTravelMinutes,
                    mathDifficulty: $0.mathDifficulty,
                    alarmSoundStyle: $0.alarmSoundStyle,
                    alarmLoudnessProfile: $0.alarmLoudnessProfile,
                    requiredCorrectMathAnswers: $0.requiredCorrectMathAnswers,
                    recoveryBoostMinutes: $0.recoveryBoostMinutes,
                    maxMissedAlarmRetries: $0.maxMissedAlarmRetries
                )
            },
            subjects: subjects.map { subject in
                ExportSubject(
                    code: subject.code,
                    title: subject.title,
                    attendanceMode: subject.attendanceModeRaw,
                    isEnabled: subject.isEnabled,
                    isOnline: subject.isOnline,
                    importance: subject.importance,
                    colorHex: subject.colorHex,
                    notes: subject.notes,
                    sessions: subject.sessions.map { session in
                        ExportSession(
                            dayOfWeek: session.dayOfWeek,
                            startMinutes: session.startMinutes,
                            endMinutes: session.endMinutes,
                            hasConflict: session.hasConflict,
                            isTemporarilyDisabled: session.isTemporarilyDisabled,
                            isPractical: session.isPractical
                        )
                    }
                )
            },
            alarms: alarms.map { alarm in
                ExportAlarm(
                    id: alarm.id.uuidString,
                    label: alarm.label,
                    kind: alarm.alarmKindRaw,
                    currentState: alarm.currentStateRaw,
                    scheduledAt: dateFmt.string(from: alarm.scheduledAt),
                    isCompleted: alarm.isCompleted,
                    isFailed: alarm.isFailed,
                    overrideUsed: alarm.overrideUsed,
                    transitions: alarm.transitions.count
                )
            },
            sleepRecommendations: recommendations.map { item in
                ExportSleepRecommendation(
                    id: item.id.uuidString,
                    date: dateFmt.string(from: item.date),
                    dayType: item.dayTypeRaw,
                    note: item.note,
                    isUserEdited: item.isUserEdited,
                    blocks: item.blocks.map { block in
                        ExportSleepBlock(
                            id: block.id.uuidString,
                            startAt: dateFmt.string(from: block.startAt),
                            endAt: dateFmt.string(from: block.endAt),
                            strategyLabel: block.strategyLabelRaw,
                            isLocked: block.isLocked
                        )
                    }
                )
            },
            sleepExecutionLogs: sleepLogs.map {
                ExportSleepExecutionLog(
                    loggedAt: dateFmt.string(from: $0.loggedAt),
                    blockId: $0.blockId.uuidString,
                    strategyLabel: $0.strategyLabel,
                    status: $0.statusRaw,
                    note: $0.note
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
