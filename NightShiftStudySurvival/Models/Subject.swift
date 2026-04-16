import Foundation
import SwiftData

@Model
final class Subject {
    var id: UUID
    var code: String
    var title: String
    var attendanceModeRaw: String
    var colorHex: String
    var isEnabled: Bool
    var isOnline: Bool
    var importance: Int
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ClassSession.subject)
    var sessions: [ClassSession]

    init(
        id: UUID = UUID(),
        code: String,
        title: String,
        attendanceMode: AttendanceMode = .normal,
        colorHex: String = "#3B82F6",
        isEnabled: Bool = true,
        isOnline: Bool = false,
        importance: Int = 2,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sessions: [ClassSession] = []
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.attendanceModeRaw = attendanceMode.rawValue
        self.colorHex = colorHex
        self.isEnabled = isEnabled
        self.isOnline = isOnline
        self.importance = importance
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessions = sessions
    }

    var attendanceMode: AttendanceMode {
        get { AttendanceMode(rawValue: attendanceModeRaw) ?? .normal }
        set {
            attendanceModeRaw = newValue.rawValue
            updatedAt = .now
        }
    }
}
