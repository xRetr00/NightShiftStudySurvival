import XCTest
@testable import NightShiftStudySurvival

final class DashboardGuidanceEngineTests: XCTestCase {
    func testReturnsLeaveNowForWorkLateEvening() {
        let engine = DashboardGuidanceEngine()
        let now = Calendar.current.date(bySettingHour: 21, minute: 45, second: 0, of: Date()) ?? Date()

        let text = engine.instruction(sessions: [], mandatory: [], now: now)
        XCTAssertEqual(text, "Leave now for work")
    }

    func testReturnsSkipGuidanceWhenOnlyOptionalClassesRemain() {
        let engine = DashboardGuidanceEngine()
        let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()

        let subject = Subject(code: "DM1", title: "Optional", attendanceMode: .dm)
        let optionalSession = ClassSession(dayOfWeek: 1, startMinutes: 13 * 60, endMinutes: 14 * 60, subject: subject)

        let text = engine.instruction(sessions: [optionalSession], mandatory: [], now: now)
        XCTAssertEqual(text, "You can skip this class")
    }

    func testReturnsMandatorySoonWhenMandatoryClassUpcoming() {
        let engine = DashboardGuidanceEngine()
        let now = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()

        let subject = Subject(code: "DVZ1", title: "Mandatory", attendanceMode: .dvz)
        let mandatorySession = ClassSession(dayOfWeek: 1, startMinutes: 11 * 60 + 20, endMinutes: 12 * 60 + 20, subject: subject)

        let text = engine.instruction(sessions: [mandatorySession], mandatory: [mandatorySession], now: now)
        XCTAssertEqual(text, "Mandatory class soon")
    }
}
