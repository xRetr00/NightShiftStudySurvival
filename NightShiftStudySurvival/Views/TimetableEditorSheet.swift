import SwiftUI

struct TimetableEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TimetableDraft
    @State private var startAt: Date
    @State private var endAt: Date

    let title: String
    let onSave: (TimetableDraft) -> Void

    init(title: String, draft: TimetableDraft, onSave: @escaping (TimetableDraft) -> Void) {
        self.title = title
        self.onSave = onSave
        _draft = State(initialValue: draft)
        _startAt = State(initialValue: Self.dateFromMinutes(draft.startMinutes))
        _endAt = State(initialValue: Self.dateFromMinutes(draft.endMinutes))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Subject") {
                    TextField("Code", text: $draft.subjectCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Title", text: $draft.subjectTitle)

                    Picker("Attendance", selection: $draft.attendanceMode) {
                        ForEach(AttendanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Online", isOn: $draft.isOnline)
                    Toggle("Practical", isOn: $draft.isPractical)

                    Stepper("Importance: \(draft.importance)", value: $draft.importance, in: 1...5)
                    TextField("Color hex", text: $draft.colorHex)
                }

                Section("Schedule") {
                    Picker("Day", selection: $draft.dayOfWeek) {
                        Text("Mon").tag(1)
                        Text("Tue").tag(2)
                        Text("Wed").tag(3)
                        Text("Thu").tag(4)
                        Text("Fri").tag(5)
                        Text("Sat").tag(6)
                        Text("Sun").tag(7)
                    }

                    DatePicker("Start", selection: $startAt, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endAt, displayedComponents: .hourAndMinute)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        draft.startMinutes = Self.minutesFromDate(startAt)
                        draft.endMinutes = max(draft.startMinutes + 10, Self.minutesFromDate(endAt))
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.subjectCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.subjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private static func dateFromMinutes(_ minutes: Int) -> Date {
        let now = Date()
        let h = (minutes / 60) % 24
        let m = minutes % 60
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
    }

    private static func minutesFromDate(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
