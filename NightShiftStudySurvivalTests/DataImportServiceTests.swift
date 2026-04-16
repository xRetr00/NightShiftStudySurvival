import SwiftData
import XCTest
@testable import NightShiftStudySurvival

@MainActor
final class DataImportServiceTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Subject.self,
            ClassSession.self,
            AppSettings.self,
            SleepRecommendation.self,
            SleepBlock.self,
            SleepExecutionLog.self,
            AlarmSchedule.self,
            AlarmTransitionLog.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    func testValidateJSONRejectsInvalidPayload() throws {
        let invalid = "{\"broken\":true"
        let error = DataImportService.validateJSON(invalid)
        XCTAssertNotNil(error)
    }

    func testPreviewJSONCountsIncomingSections() throws {
        let context = try makeContext()
        let raw = sampleJSON()

        let preview = DataImportService.previewJSON(raw, context: context)
        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.incomingSettings, 1)
        XCTAssertEqual(preview?.incomingSubjects, 1)
        XCTAssertEqual(preview?.incomingSessions, 1)
        XCTAssertEqual(preview?.incomingAlarms, 1)
        XCTAssertEqual(preview?.incomingSleepRecommendations, 1)
        XCTAssertEqual(preview?.incomingSleepLogs, 1)
    }

    func testSelectiveImportTimetableOnly() throws {
        let context = try makeContext()
        let raw = sampleJSON()

        let selection = ImportSelection(
            settings: false,
            timetable: true,
            alarms: false,
            sleepPlans: false,
            sleepLogs: false
        )

        _ = DataImportService.importJSON(raw, context: context, selection: selection, wipeSelectedSections: true)

        let subjects = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        let alarms = (try? context.fetch(FetchDescriptor<AlarmSchedule>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []

        XCTAssertEqual(subjects.count, 1)
        XCTAssertTrue(alarms.isEmpty)
        XCTAssertTrue(settings.isEmpty)
    }

    private func sampleJSON() -> String {
        """
        {
          "settings": {
            "workStartMinutes": 1320,
            "workEndMinutes": 300,
            "homeToUniversityTravelMinutes": 45,
            "workToHomeTravelMinutes": 30,
            "homeToWorkTravelMinutes": 0,
            "mathDifficulty": "Medium",
            "alarmSoundStyle": "Default",
            "alarmLoudnessProfile": "High",
            "requiredCorrectMathAnswers": 3,
            "recoveryBoostMinutes": 40,
            "maxMissedAlarmRetries": 2
          },
          "subjects": [
            {
              "code": "CE999",
              "title": "Test Subject",
              "attendanceMode": "Normal",
              "isEnabled": true,
              "isOnline": false,
              "importance": 2,
              "colorHex": "#3B82F6",
              "notes": "",
              "sessions": [
                {
                  "dayOfWeek": 1,
                  "startMinutes": 540,
                  "endMinutes": 600,
                  "hasConflict": false,
                  "isTemporarilyDisabled": false,
                  "isPractical": false
                }
              ]
            }
          ],
          "alarms": [
            {
              "label": "Test Alarm",
              "kind": "Wake for Class",
              "currentState": "PreAlarm",
              "scheduledAt": "2026-04-16T10:00:00Z",
              "isCompleted": false,
              "isFailed": false,
              "overrideUsed": false,
              "transitions": 0
            }
          ],
          "sleepRecommendations": [
            {
              "date": "2026-04-16T00:00:00Z",
              "dayType": "Recovery Day",
              "note": "n",
              "isUserEdited": false,
              "blocks": [
                {
                  "startAt": "2026-04-16T07:00:00Z",
                  "endAt": "2026-04-16T10:00:00Z",
                  "strategyLabel": "Recovery day",
                  "isLocked": false
                }
              ]
            }
          ],
          "sleepExecutionLogs": [
            {
              "loggedAt": "2026-04-16T08:00:00Z",
              "strategyLabel": "Recovery day",
              "status": "Followed",
              "note": "ok"
            }
          ]
        }
        """
    }
}
