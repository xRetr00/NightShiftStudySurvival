import SwiftUI
import SwiftData
import UserNotifications

@main
struct NightShiftStudySurvivalApp: App {
    private let container: ModelContainer

    init() {
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

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        container = try! ModelContainer(for: schema, configurations: [configuration])

        SeedDataLoader.seedIfNeeded(context: container.mainContext)
        AppNotificationDelegate.shared.configure(context: container.mainContext)
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(context: container.mainContext)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
