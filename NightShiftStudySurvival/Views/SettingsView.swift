import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    let context: ModelContext

    @State private var settings: AppSettings?
    @State private var exportJSON = ""
    @State private var exportMessage: String?
    @State private var importJSON = ""
    @State private var importPreview: ImportPreview?
    @State private var importSettings = true
    @State private var importTimetable = true
    @State private var importAlarms = true
    @State private var importSleepPlans = true
    @State private var importSleepLogs = true
    @State private var wipeBeforeImport = true

    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    Section("Work") {
                        stepperRow(
                            title: "Work start (min)",
                            value: Binding(
                                get: { settings.workStartMinutes },
                                set: { settings.workStartMinutes = $0; persist() }
                            ),
                            range: 0...1439,
                            step: 5
                        )

                        stepperRow(
                            title: "Work end (min)",
                            value: Binding(
                                get: { settings.workEndMinutes },
                                set: { settings.workEndMinutes = $0; persist() }
                            ),
                            range: 0...1439,
                            step: 5
                        )
                    }

                    Section("Travel") {
                        stepperRow(
                            title: "Home -> University",
                            value: Binding(
                                get: { settings.homeToUniversityTravelMinutes },
                                set: { settings.homeToUniversityTravelMinutes = $0; persist() }
                            ),
                            range: 0...180,
                            step: 5
                        )

                        stepperRow(
                            title: "Work -> Home",
                            value: Binding(
                                get: { settings.workToHomeTravelMinutes },
                                set: { settings.workToHomeTravelMinutes = $0; persist() }
                            ),
                            range: 0...180,
                            step: 5
                        )
                    }

                    Section("Math Lock") {
                        Stepper("Required correct answers: \(settings.requiredCorrectMathAnswers)", value: Binding(
                            get: { settings.requiredCorrectMathAnswers },
                            set: { settings.requiredCorrectMathAnswers = $0; persist() }
                        ), in: 2...7)

                        Picker("Difficulty", selection: Binding(
                            get: { settings.mathDifficulty },
                            set: { settings.mathDifficulty = $0; persist() }
                        )) {
                            Text("Easy").tag("Easy")
                            Text("Medium").tag("Medium")
                            Text("Brutal").tag("Brutal")
                        }

                        Toggle("Auto-adjust difficulty", isOn: Binding(
                            get: { settings.autoAdjustMathDifficulty },
                            set: { settings.autoAdjustMathDifficulty = $0; persist() }
                        ))

                        Stepper("Max missed retries: \(settings.maxMissedAlarmRetries)", value: Binding(
                            get: { settings.maxMissedAlarmRetries },
                            set: { settings.maxMissedAlarmRetries = $0; persist() }
                        ), in: 0...5)
                    }

                    Section("Alarm Audio") {
                        Picker("Sound style", selection: Binding(
                            get: { settings.alarmSoundStyle },
                            set: { settings.alarmSoundStyle = $0; persist() }
                        )) {
                            Text("Default").tag("Default")
                            Text("Siren").tag("Siren")
                            Text("Industrial").tag("Industrial")
                        }

                        Picker("Loudness profile", selection: Binding(
                            get: { settings.alarmLoudnessProfile },
                            set: { settings.alarmLoudnessProfile = $0; persist() }
                        )) {
                            Text("Low").tag("Low")
                            Text("Medium").tag("Medium")
                            Text("High").tag("High")
                            Text("Max").tag("Max")
                        }
                    }

                    Section("Recovery") {
                        Stepper("Recovery boost (min): \(settings.recoveryBoostMinutes)", value: Binding(
                            get: { settings.recoveryBoostMinutes },
                            set: { settings.recoveryBoostMinutes = $0; persist() }
                        ), in: 0...180, step: 10)

                        Toggle("Show heavy-day prep reminder", isOn: Binding(
                            get: { settings.showHeavyDayPrepReminder },
                            set: { settings.showHeavyDayPrepReminder = $0; persist() }
                        ))
                    }

                    Section("Dashboard") {
                        Toggle("Show DM classes", isOn: Binding(
                            get: { settings.showDMOnDashboard },
                            set: { settings.showDMOnDashboard = $0; persist() }
                        ))

                        Toggle("Auto-hide skipped classes", isOn: Binding(
                            get: { settings.autoHideSkippedClasses },
                            set: { settings.autoHideSkippedClasses = $0; persist() }
                        ))
                    }

                    Section("Accessibility") {
                        Toggle("High contrast mode", isOn: Binding(
                            get: { settings.highContrastMode },
                            set: { settings.highContrastMode = $0; persist() }
                        ))

                        Toggle("Strong haptics", isOn: Binding(
                            get: { settings.enableStrongHaptics },
                            set: { settings.enableStrongHaptics = $0; persist() }
                        ))
                    }

                    Section("Data Export") {
                        Button("Generate JSON export") {
                            exportJSON = DataExportService.exportJSON(context: context) ?? ""
                            exportMessage = exportJSON.isEmpty ? "Failed to generate export." : "Export generated."
                        }

                        if !exportJSON.isEmpty {
                            Button("Copy export to clipboard") {
                                UIPasteboard.general.string = exportJSON
                                exportMessage = "Export copied to clipboard."
                            }

                            TextEditor(text: $exportJSON)
                                .frame(minHeight: 140)
                                .font(.caption.monospaced())
                        }

                        if let exportMessage {
                            Text(exportMessage)
                                .font(.caption)
                                .foregroundStyle(AppTheme.info)
                        }
                    }

                    Section("Data Import") {
                        Text("Paste export JSON below to restore local backup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $importJSON)
                            .frame(minHeight: 140)
                            .font(.caption.monospaced())

                        Button("Validate + Preview") {
                            if let error = DataImportService.validateJSON(importJSON) {
                                importPreview = nil
                                exportMessage = error
                                return
                            }

                            importPreview = DataImportService.previewJSON(importJSON, context: context)
                            exportMessage = importPreview == nil ? "Could not generate preview." : "Preview ready."
                        }
                        .disabled(importJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let importPreview {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(importPreview.summary)
                                    .font(.caption)

                                if !importPreview.warnings.isEmpty {
                                    ForEach(importPreview.warnings, id: \.self) { warning in
                                        Text("- \(warning)")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.warning)
                                    }
                                }

                                Text("Existing vs incoming")
                                    .font(.caption.weight(.semibold))
                                Text("Settings: \(importPreview.existingSettings) -> \(importPreview.incomingSettings)")
                                    .font(.caption2)
                                Text("Timetable subjects: \(importPreview.existingSubjects) -> \(importPreview.incomingSubjects)")
                                    .font(.caption2)
                                Text("Sessions: \(importPreview.existingSessions) -> \(importPreview.incomingSessions)")
                                    .font(.caption2)
                                Text("Alarms: \(importPreview.existingAlarms) -> \(importPreview.incomingAlarms)")
                                    .font(.caption2)
                                Text("Sleep plans: \(importPreview.existingSleepRecommendations) -> \(importPreview.incomingSleepRecommendations)")
                                    .font(.caption2)
                                Text("Sleep logs: \(importPreview.existingSleepLogs) -> \(importPreview.incomingSleepLogs)")
                                    .font(.caption2)
                            }
                        }

                        Toggle("Import settings", isOn: $importSettings)
                        Toggle("Import timetable", isOn: $importTimetable)
                        Toggle("Import alarms", isOn: $importAlarms)
                        Toggle("Import sleep plans", isOn: $importSleepPlans)
                        Toggle("Import sleep logs", isOn: $importSleepLogs)
                        Toggle("Wipe selected sections first", isOn: $wipeBeforeImport)

                        Button("Import JSON backup") {
                            let selection = ImportSelection(
                                settings: importSettings,
                                timetable: importTimetable,
                                alarms: importAlarms,
                                sleepPlans: importSleepPlans,
                                sleepLogs: importSleepLogs
                            )

                            exportMessage = DataImportService.importJSON(
                                importJSON,
                                context: context,
                                selection: selection,
                                wipeSelectedSections: wipeBeforeImport
                            )
                            loadSettings()
                        }
                        .disabled(importJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    Text("Loading settings...")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
        }
        .onAppear {
            loadSettings()
        }
    }

    @ViewBuilder
    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Stepper("\(value.wrappedValue)", value: value, in: range, step: step)
        }
    }

    private func loadSettings() {
        let descriptor = FetchDescriptor<AppSettings>()
        settings = (try? context.fetch(descriptor))?.first
    }

    private func persist() {
        try? context.save()
    }
}
