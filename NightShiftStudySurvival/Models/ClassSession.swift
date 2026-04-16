import Foundation
import SwiftData

@Model
final class ClassSession {
    var id: UUID
    var dayOfWeek: Int
    var startMinutes: Int
    var endMinutes: Int
    var location: String
    var isTemporarilyDisabled: Bool
    var hasConflict: Bool
    var isPractical: Bool
    var createdAt: Date
    var updatedAt: Date

    var subject: Subject?

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        startMinutes: Int,
        endMinutes: Int,
        location: String = "",
        isTemporarilyDisabled: Bool = false,
        hasConflict: Bool = false,
        isPractical: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        subject: Subject? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.location = location
        self.isTemporarilyDisabled = isTemporarilyDisabled
        self.hasConflict = hasConflict
        self.isPractical = isPractical
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.subject = subject
    }

    var durationMinutes: Int {
        max(0, endMinutes - startMinutes)
    }

    var startTimeLabel: String {
        Self.minutesToLabel(startMinutes)
    }

    var endTimeLabel: String {
        Self.minutesToLabel(endMinutes)
    }

    private static func minutesToLabel(_ minutes: Int) -> String {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}
