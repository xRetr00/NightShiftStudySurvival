import Foundation

struct DashboardGuidanceEngine {
    func instruction(
        sessions: [ClassSession],
        mandatory: [ClassSession],
        now: Date,
        leaveBufferMinutes: Int = 45
    ) -> String {
        let minutesNow = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)

        if minutesNow >= 21 * 60 + 30 {
            return "Leave now for work"
        }

        if minutesNow <= 7 * 60 {
            return sessions.isEmpty ? "Sleep now" : "Emergency morning sleep"
        }

        if let nextMandatory = mandatory.first(where: { $0.startMinutes > minutesNow }) {
            let leaveAt = max(0, nextMandatory.startMinutes - leaveBufferMinutes)
            if minutesNow >= leaveAt {
                return "Leave now for class"
            }
            return "Mandatory class soon"
        }

        if mandatory.isEmpty && !sessions.isEmpty {
            return "You can skip this class"
        }

        return "Main recovery sleep after classes"
    }
}
