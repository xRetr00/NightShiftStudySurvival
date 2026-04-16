import SwiftUI
import SwiftData

struct WeeklyTimetableView: View {
    @StateObject private var viewModel: TimetableViewModel
    @State private var editorDraft = TimetableDraft()
    @State private var editingSession: ClassSession?
    @State private var showEditor = false

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: TimetableViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.conflicts.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active overlaps: \(viewModel.conflicts.count)")
                                .foregroundStyle(AppTheme.warning)

                            ForEach(viewModel.conflicts.prefix(3)) { conflict in
                                Text("\(weekdayLabel(conflict.dayOfWeek)) overlap \(conflict.overlapLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                            }

                            Button("Auto resolve by attendance priority") {
                                viewModel.autoResolveConflictsByAttendance()
                            }
                            .buttonStyle(SurvivalButtonStyle(color: AppTheme.warning))
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppTheme.card)
                }

                ForEach(viewModel.subjects, id: \.id) { subject in
                    Section {
                        attendanceModePicker(for: subject)

                        ForEach(subject.sessions, id: \.id) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(weekdayLabel(session.dayOfWeek))  \(session.startTimeLabel)-\(session.endTimeLabel)")
                                        .foregroundStyle(.white)
                                    if session.hasConflict {
                                        Text("Conflict")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.warning)
                                    }
                                }

                                Spacer()

                                Toggle("Disabled", isOn: Binding(
                                    get: { session.isTemporarilyDisabled },
                                    set: { value in
                                        viewModel.setTemporaryDisabled(session, disabled: value)
                                    }
                                ))
                                .labelsHidden()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editorDraft = TimetableDraft(session: session)
                                editingSession = session
                                showEditor = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteSession(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editorDraft = TimetableDraft(session: session)
                                    editingSession = session
                                    showEditor = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.info)
                            }
                            .listRowBackground(AppTheme.card)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(subject.code)  \(subject.title)")
                            Text(subject.attendanceMode.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Weekly Timetable")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorDraft = TimetableDraft()
                        editingSession = nil
                        showEditor = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear {
            viewModel.reload()
        }
        .sheet(isPresented: $showEditor) {
            TimetableEditorSheet(
                title: editingSession == nil ? "Add Class" : "Edit Class",
                draft: editorDraft
            ) { updated in
                if let editingSession {
                    viewModel.updateSession(editingSession, with: updated)
                } else {
                    viewModel.addSession(from: updated)
                }
                self.editingSession = nil
            }
        }
    }

    private func attendanceModePicker(for subject: Subject) -> some View {
        Picker("Attendance", selection: Binding(
            get: { subject.attendanceMode },
            set: { mode in
                viewModel.setAttendanceMode(subject: subject, mode: mode)
            }
        )) {
            ForEach(AttendanceMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .listRowBackground(AppTheme.card)
    }

    private func weekdayLabel(_ day: Int) -> String {
        switch day {
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        case 7: return "Sun"
        default: return "?"
        }
    }
}
