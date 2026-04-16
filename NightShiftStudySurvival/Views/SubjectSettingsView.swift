import SwiftUI
import SwiftData

struct SubjectSettingsView: View {
    @StateObject private var viewModel: TimetableViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: TimetableViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.subjects, id: \.id) { subject in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(subject.code)  \(subject.title)")
                            .foregroundStyle(.white)

                        Picker("Mode", selection: Binding(
                            get: { subject.attendanceMode },
                            set: { mode in viewModel.setAttendanceMode(subject: subject, mode: mode) }
                        )) {
                            ForEach(AttendanceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Enabled", isOn: Binding(
                            get: { subject.isEnabled },
                            set: { _ in viewModel.toggleSubjectEnabled(subject) }
                        ))
                        .tint(AppTheme.safe)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(AppTheme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Subject Settings")
        }
        .onAppear {
            viewModel.reload()
        }
    }
}
