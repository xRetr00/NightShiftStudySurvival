import XCTest
@testable import NightShiftStudySurvival

final class ConflictDetectionEngineTests: XCTestCase {
    func testDetectsOverlapOnSameDay() {
        let subject = Subject(code: "T1", title: "Test")
        let a = ClassSession(dayOfWeek: 3, startMinutes: 13 * 60 + 30, endMinutes: 15 * 60, subject: subject)
        let b = ClassSession(dayOfWeek: 3, startMinutes: 14 * 60 + 10, endMinutes: 16 * 60, subject: subject)

        let engine = ConflictDetectionEngine()
        let conflicts = engine.detectConflicts(in: [a, b])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.dayOfWeek, 3)
        XCTAssertEqual(conflicts.first?.overlapStartMinutes, 14 * 60 + 10)
    }

    func testIgnoresDisabledSessionInOverlapScan() {
        let subject = Subject(code: "T2", title: "Test")
        let active = ClassSession(dayOfWeek: 2, startMinutes: 9 * 60, endMinutes: 10 * 60, subject: subject)
        let disabled = ClassSession(dayOfWeek: 2, startMinutes: 9 * 60 + 30, endMinutes: 10 * 60 + 30, isTemporarilyDisabled: true, subject: subject)

        let engine = ConflictDetectionEngine()
        let conflicts = engine.detectConflicts(in: [active, disabled])

        XCTAssertTrue(conflicts.isEmpty)
    }
}
