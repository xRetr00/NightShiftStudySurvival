import Foundation
import SwiftData

@MainActor
final class TimetableViewModel: ObservableObject {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var conflicts: [SessionConflict] = []

    private let context: ModelContext
    private let conflictEngine = ConflictDetectionEngine()

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.code)])
        subjects = (try? context.fetch(descriptor)) ?? []
        recomputeConflicts()
    }

    func setAttendanceMode(subject: Subject, mode: AttendanceMode) {
        subject.attendanceMode = mode
        subject.updatedAt = .now
        try? context.save()
        reload()
    }

    func toggleSubjectEnabled(_ subject: Subject) {
        subject.isEnabled.toggle()
        subject.updatedAt = .now
        try? context.save()
        reload()
    }

    func setTemporaryDisabled(_ session: ClassSession, disabled: Bool) {
        session.isTemporarilyDisabled = disabled
        session.updatedAt = .now
        try? context.save()
        reload()
    }

    func addSession(from draft: TimetableDraft) {
        let subject = upsertSubject(from: draft)

        let session = ClassSession(
            dayOfWeek: normalizedDay(draft.dayOfWeek),
            startMinutes: clampMinutes(draft.startMinutes),
            endMinutes: normalizedEnd(start: draft.startMinutes, end: draft.endMinutes),
            location: draft.isOnline ? "Online" : "Campus",
            isTemporarilyDisabled: false,
            hasConflict: false,
            isPractical: draft.isPractical,
            subject: subject
        )

        if !subject.sessions.contains(where: { $0.id == session.id }) {
            subject.sessions.append(session)
        }

        context.insert(session)
        subject.updatedAt = .now
        try? context.save()
        reload()
    }

    func updateSession(_ session: ClassSession, with draft: TimetableDraft) {
        let targetSubject = upsertSubject(from: draft)
        let oldSubject = session.subject

        if oldSubject?.id != targetSubject.id {
            oldSubject?.sessions.removeAll(where: { $0.id == session.id })
            session.subject = targetSubject
            if !targetSubject.sessions.contains(where: { $0.id == session.id }) {
                targetSubject.sessions.append(session)
            }
        }

        session.dayOfWeek = normalizedDay(draft.dayOfWeek)
        session.startMinutes = clampMinutes(draft.startMinutes)
        session.endMinutes = normalizedEnd(start: draft.startMinutes, end: draft.endMinutes)
        session.location = draft.isOnline ? "Online" : "Campus"
        session.isPractical = draft.isPractical
        session.updatedAt = .now

        targetSubject.updatedAt = .now
        try? context.save()

        deleteSubjectIfEmpty(oldSubject)
        reload()
    }

    func deleteSession(_ session: ClassSession) {
        let subject = session.subject
        subject?.sessions.removeAll(where: { $0.id == session.id })
        context.delete(session)

        deleteSubjectIfEmpty(subject)
        try? context.save()
        reload()
    }

    func autoResolveConflictsByAttendance() {
        guard !conflicts.isEmpty else { return }

        for conflict in conflicts {
            let ranked = conflict.sessions.sorted { lhs, rhs in
                let left = rank(for: lhs)
                let right = rank(for: rhs)
                if left == right {
                    return lhs.durationMinutes > rhs.durationMinutes
                }
                return left > right
            }

            guard let keep = ranked.first else { continue }
            for session in ranked where session.id != keep.id {
                session.isTemporarilyDisabled = true
                session.updatedAt = .now
            }
        }

        try? context.save()
        reload()
    }

    private func recomputeConflicts() {
        let sessions = subjects.flatMap(\.sessions)
        let detected = conflictEngine.detectConflicts(in: sessions)
        conflicts = detected

        // Rebuild hasConflict flags based on actual overlap detection.
        for session in sessions {
            session.hasConflict = false
        }
        for conflict in detected {
            for session in conflict.sessions {
                session.hasConflict = true
            }
        }

        try? context.save()
    }

    private func rank(for session: ClassSession) -> Int {
        guard let subject = session.subject else { return 0 }
        let modeScore: Int
        switch subject.attendanceMode {
        case .dvz: modeScore = 30
        case .normal: modeScore = 20
        case .dm: modeScore = 10
        }

        return modeScore + subject.importance
    }

    private func upsertSubject(from draft: TimetableDraft) -> Subject {
        let descriptor = FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.code)])
        let existing = (try? context.fetch(descriptor)) ?? []

        if let found = existing.first(where: { $0.code.caseInsensitiveCompare(draft.subjectCode.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }) {
            found.title = draft.subjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            found.attendanceMode = draft.attendanceMode
            found.isOnline = draft.isOnline
            found.importance = draft.importance
            found.notes = draft.notes
            found.colorHex = draft.colorHex
            found.updatedAt = .now
            return found
        }

        let subject = Subject(
            code: draft.subjectCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            title: draft.subjectTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            attendanceMode: draft.attendanceMode,
            colorHex: draft.colorHex,
            isEnabled: true,
            isOnline: draft.isOnline,
            importance: draft.importance,
            notes: draft.notes
        )
        context.insert(subject)
        return subject
    }

    private func deleteSubjectIfEmpty(_ subject: Subject?) {
        guard let subject else { return }
        if subject.sessions.isEmpty {
            context.delete(subject)
        }
    }

    private func normalizedDay(_ day: Int) -> Int {
        min(7, max(1, day))
    }

    private func clampMinutes(_ value: Int) -> Int {
        min(1439, max(0, value))
    }

    private func normalizedEnd(start: Int, end: Int) -> Int {
        let safeStart = clampMinutes(start)
        let safeEnd = clampMinutes(end)
        if safeEnd <= safeStart {
            return min(1439, safeStart + 30)
        }
        return safeEnd
    }
}
