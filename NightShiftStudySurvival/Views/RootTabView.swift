import SwiftUI
import SwiftData

struct RootTabView: View {
    let context: ModelContext

    var body: some View {
        TabView {
            TodayDashboardView(context: context)
                .tabItem {
                    Label("Today", systemImage: "gauge.with.needle")
                }

            WeeklyTimetableView(context: context)
                .tabItem {
                    Label("Timetable", systemImage: "calendar")
                }

            AlarmCenterView(context: context)
                .tabItem {
                    Label("Alarms", systemImage: "alarm")
                }

            SleepPlanView(context: context)
                .tabItem {
                    Label("Sleep", systemImage: "bed.double")
                }

            SubjectSettingsView(context: context)
                .tabItem {
                    Label("Subjects", systemImage: "slider.horizontal.3")
                }

            StatisticsView(context: context)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            SettingsView(context: context)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(AppTheme.critical)
        .background(AppTheme.background.ignoresSafeArea())
    }
}
