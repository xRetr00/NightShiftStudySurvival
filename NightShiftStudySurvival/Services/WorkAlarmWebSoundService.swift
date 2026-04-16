import Foundation

struct WorkAlarmWebSoundService {
    private let dailyNames = [
        "web_disaster",
        "web_nuclear",
        "web_red_alert"
    ]

    func dailySoundName(for date: Date = .now) -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (max(1, dayOfYear) - 1) % dailyNames.count
        return dailyNames[index]
    }

    func allSoundNames() -> [String] {
        dailyNames
    }
}
