import Foundation
import SwiftData

@MainActor
enum SeedDataLoader {
    private static let seedKey = "NightShiftStudySurvival.Seeded.v1"

    static func seedIfNeeded(context: ModelContext) {
        if UserDefaults.standard.bool(forKey: seedKey) {
            return
        }

        if fetchSubjectCount(context: context) > 0 {
            UserDefaults.standard.set(true, forKey: seedKey)
            return
        }

        insertDefaultSettingsIfMissing(context: context)
        insertSeededTimetable(context: context)

        try? context.save()
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    private static func fetchSubjectCount(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Subject>()
        let items = (try? context.fetch(descriptor)) ?? []
        return items.count
    }

    private static func insertDefaultSettingsIfMissing(context: ModelContext) {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(settingsDescriptor), !existing.isEmpty {
            return
        }

        context.insert(AppSettings())
    }

    private static func insertSeededTimetable(context: ModelContext) {
        let mondayCE206 = createSubject(code: "CE206", title: "Digital Electronics", mode: .normal, color: "#1F6FEB")
        mondayCE206.sessions.append(createSession(day: 1, start: "08:30", end: "09:10", practical: true, subject: mondayCE206))

        let mth102 = createSubject(code: "MTH102", title: "Mathematics II", mode: .normal, color: "#FF8A00")
        mth102.sessions.append(createSession(day: 1, start: "09:20", end: "12:30", subject: mth102))

        let ce104 = createSubject(code: "CE104", title: "Web Technologies", mode: .normal, color: "#2EA043")
        ce104.sessions.append(createSession(day: 1, start: "13:00", end: "15:20", subject: ce104))

        let aib102 = createSubject(code: "AIB102", title: "Ataturk Principles and History II", mode: .normal, color: "#D29922")
        aib102.sessions.append(createSession(day: 1, start: "15:30", end: "17:00", subject: aib102))

        let tdb122 = createSubject(code: "TDB122", title: "Turk Dili II", mode: .normal, color: "#A371F7")
        tdb122.sessions.append(createSession(day: 1, start: "17:00", end: "18:30", subject: tdb122))

        let ce208 = createSubject(code: "CE208", title: "Object Oriented Analysis and Design", mode: .normal, color: "#58A6FF")
        ce208.sessions.append(createSession(day: 2, start: "09:20", end: "11:40", subject: ce208))

        let cekrp102 = createSubject(code: "CEKRP102", title: "Career Planning", mode: .normal, color: "#3FB950")
        cekrp102.sessions.append(createSession(day: 2, start: "16:20", end: "17:00", subject: cekrp102))

        let ue211 = createSubject(code: "UE211", title: "Business Psychology", mode: .normal, color: "#F85149")
        ue211.sessions.append(createSession(day: 3, start: "08:30", end: "10:00", subject: ue211))

        let ce102 = createSubject(code: "CE102", title: "Algorithms and Programming II", mode: .normal, color: "#8957E5")
        ce102.sessions.append(createSession(day: 3, start: "13:50", end: "16:10", hasConflict: true, subject: ce102))

        let ing122 = createSubject(code: "ING122", title: "Academic English II", mode: .normal, color: "#FF7B72")
        ing122.sessions.append(createSession(day: 3, start: "15:30", end: "17:00", hasConflict: true, subject: ing122))

        let phy104 = createSubject(code: "PHY104", title: "Physics II", mode: .normal, color: "#56D364")
        phy104.sessions.append(createSession(day: 4, start: "09:20", end: "11:40", subject: phy104))

        let ce106 = createSubject(code: "CE106", title: "Probability and Statistics", mode: .normal, color: "#FFA657")
        ce106.sessions.append(createSession(day: 4, start: "13:00", end: "15:20", subject: ce106))

        let all = [
            mondayCE206, mth102, ce104, aib102, tdb122,
            ce208, cekrp102, ue211, ce102, ing122, phy104, ce106
        ]

        for subject in all {
            context.insert(subject)
            for session in subject.sessions {
                context.insert(session)
            }
        }
    }

    private static func createSubject(code: String, title: String, mode: AttendanceMode, color: String) -> Subject {
        Subject(code: code, title: title, attendanceMode: mode, colorHex: color)
    }

    private static func createSession(
        day: Int,
        start: String,
        end: String,
        practical: Bool = false,
        hasConflict: Bool = false,
        subject: Subject
    ) -> ClassSession {
        ClassSession(
            dayOfWeek: day,
            startMinutes: toMinutes(start),
            endMinutes: toMinutes(end),
            location: subject.isOnline ? "Online" : "Campus",
            isTemporarilyDisabled: false,
            hasConflict: hasConflict,
            isPractical: practical,
            subject: subject
        )
    }

    private static func toMinutes(_ value: String) -> Int {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return 0
        }
        return hours * 60 + minutes
    }
}
