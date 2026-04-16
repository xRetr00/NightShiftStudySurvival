import XCTest
@testable import NightShiftStudySurvival

final class RecoveryOptimizationEngineTests: XCTestCase {
    func testLowAdherenceReducesPlanComplexity() {
        let engine = RecoveryOptimizationEngine()
        let context = RecoveryContext(
            dayType: .heavy,
            tomorrowDayType: .medium,
            sleepFollowRate: 0.2,
            recentMissedAlarms: 3,
            recoveryBoostMinutes: 30
        )

        let adjustment = engine.adjust(for: context)

        XCTAssertTrue(adjustment.reducePlanComplexity)
        XCTAssertTrue(adjustment.addPreWorkReset)
        XCTAssertGreaterThan(adjustment.mainSleepExtensionMinutes, 0)
    }

    func testRecoveryDayExtendsMainSleep() {
        let engine = RecoveryOptimizationEngine()
        let context = RecoveryContext(
            dayType: .recovery,
            tomorrowDayType: .heavy,
            sleepFollowRate: 0.9,
            recentMissedAlarms: 0,
            recoveryBoostMinutes: 40
        )

        let adjustment = engine.adjust(for: context)

        XCTAssertGreaterThanOrEqual(adjustment.mainSleepExtensionMinutes, 60)
        XCTAssertTrue(adjustment.adviseEarlySleep)
    }
}
