import Foundation

struct TimetableDraft {
    var subjectCode: String
    var subjectTitle: String
    var attendanceMode: AttendanceMode
    var dayOfWeek: Int
    var startMinutes: Int
    var endMinutes: Int
    var isPractical: Bool
    var isOnline: Bool
    var importance: Int
    var notes: String
    var colorHex: String

    init(
        subjectCode: String = "",
        subjectTitle: String = "",
        attendanceMode: AttendanceMode = .normal,
        dayOfWeek: Int = 1,
        startMinutes: Int = 9 * 60,
        endMinutes: Int = 10 * 60,
        isPractical: Bool = false,
        isOnline: Bool = false,
        importance: Int = 2,
        notes: String = "",
        colorHex: String = "#3B82F6"
    ) {
        self.subjectCode = subjectCode
        self.subjectTitle = subjectTitle
        self.attendanceMode = attendanceMode
        self.dayOfWeek = dayOfWeek
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.isPractical = isPractical
        self.isOnline = isOnline
        self.importance = importance
        self.notes = notes
        self.colorHex = colorHex
    }

    init(session: ClassSession) {
        self.subjectCode = session.subject?.code ?? ""
        self.subjectTitle = session.subject?.title ?? ""
        self.attendanceMode = session.subject?.attendanceMode ?? .normal
        self.dayOfWeek = session.dayOfWeek
        self.startMinutes = session.startMinutes
        self.endMinutes = session.endMinutes
        self.isPractical = session.isPractical
        self.isOnline = session.subject?.isOnline ?? false
        self.importance = session.subject?.importance ?? 2
        self.notes = session.subject?.notes ?? ""
        self.colorHex = session.subject?.colorHex ?? "#3B82F6"
    }
}
