import SwiftData
import SwiftUI

/// Three exercises, one screen each. Skip any he did not do. Save writes one
/// stored session per exercise he kept. Nothing here schedules a reminder.
struct GuidedSessionFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]
    @Query private var settingsList: [AppSettings]

    @State private var edits: [ExerciseEntryDraft]?
    @State private var index = 0
    @State private var issue: String?
    @State private var saveError: String?

    private var exercises: [ExerciseEntryDraft] {
        edits ?? GuidedSessionDraft.exercises(from: sessions.map(\.snapshot))
    }

    private var stepCount: Int { SessionExerciseKind.loggable.count }
    private var onReview: Bool { index >= stepCount }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if onReview {
                        review
                    } else {
                        exerciseStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
            .appCanvas()
            .navigationTitle(onReview ? "Review" : "Log a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("guided-back")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("guided-close")
                }
            }
        }
        .accessibilityIdentifier("guided-session-screen")
        .preferredColorScheme(.dark)
    }

    private var exerciseStep: some View {
        let draft = exercises[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("\(index + 1) of \(stepCount)")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.gold)
                Text(draft.kind.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("guided-exercise-title")

                if draft.kind.usesHold {
                    quantityRow(
                        title: "Weight",
                        value: LoadCopy.labeled(draft.loadLbs),
                        identifier: "guided-load"
                    ) { stepLoad($0) }
                    quantityRow(
                        title: "Holds",
                        value: "\(draft.sets)",
                        identifier: "guided-holds"
                    ) { stepCount(\.sets, by: $0, ceiling: ExerciseEntry.maxCount) }
                    quantityRow(
                        title: "Seconds",
                        value: "\(draft.holdSeconds)s",
                        identifier: "guided-seconds"
                    ) { stepHold($0) }
                } else {
                    quantityRow(
                        title: "Weight",
                        value: LoadCopy.labeled(draft.loadLbs),
                        identifier: "guided-load"
                    ) { stepLoad($0) }
                    quantityRow(
                        title: "Sets",
                        value: "\(draft.sets)",
                        identifier: "guided-sets"
                    ) { stepCount(\.sets, by: $0, ceiling: ExerciseEntry.maxCount) }
                    quantityRow(
                        title: "Reps",
                        value: "\(draft.reps)",
                        identifier: "guided-reps"
                    ) { stepCount(\.reps, by: $0, ceiling: ExerciseEntry.maxReps) }
                }

                painRow(selected: draft.pain)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var review: some View {
        let logs = GuidedSessionDraft.logs(from: exercises)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Save the exercises you did.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.ivory)
                if logs.isEmpty {
                    Text("Every exercise was skipped. Go back to log one, or close.")
                        .font(.body)
                        .foregroundStyle(AppTheme.quiet)
                } else {
                    ForEach(logs, id: \.kind) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.kind.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.ivory)
                            if let dose = SessionSummary.compactResistance(log.sets) {
                                Text(dose)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.quiet)
                            }
                            Text("Pain \(log.painDuring)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.gold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .posterCard()
                    }
                }
                if let saveError {
                    Text(saveError)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.gold)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let issue, !onReview {
                Text(issue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("guided-issue")
            }
            if onReview {
                let ready = !GuidedSessionDraft.logs(from: exercises).isEmpty
                Button(ready ? "Save session" : "Close") {
                    if ready { save() } else { dismiss() }
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier("guided-save")
            } else {
                HStack(spacing: 12) {
                    Button("Skip") { skip() }
                        .buttonStyle(.secondaryAction)
                        .accessibilityIdentifier("guided-skip")
                    Button("Next") { advance() }
                        .buttonStyle(.primaryAction)
                        .accessibilityIdentifier("guided-next")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(AppTheme.canvas.ignoresSafeArea(edges: .bottom))
    }

    private func quantityRow(
        title: String,
        value: String,
        identifier: String,
        step: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
                Text(value)
                    .font(.title.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.ivory)
            }
            Spacer()
            HStack(spacing: 10) {
                stepButton(systemName: "minus", identifier: "\(identifier)-minus") { step(-1) }
                stepButton(systemName: "plus", identifier: "\(identifier)-plus") { step(1) }
            }
        }
        .padding(14)
        .posterCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func stepButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, height: 48)
                .background(Circle().fill(AppTheme.gold))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(systemName == "plus" ? "Increase" : "Decrease")
    }

    private func painRow(selected: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pain during")
                .font(.subheadline)
                .foregroundStyle(AppTheme.quiet)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(0...10, id: \.self) { score in
                    Button {
                        mutate { $0.pain = score }
                        issue = nil
                    } label: {
                        Text("\(score)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(selected == score ? AppTheme.ink : AppTheme.ivory)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected == score ? AppTheme.gold : AppTheme.quietFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pain \(score)")
                    .accessibilityIdentifier("guided-pain-\(score)")
                }
            }
        }
    }

    private func mutate(_ change: (inout ExerciseEntryDraft) -> Void) {
        var next = exercises
        guard next.indices.contains(index) else { return }
        change(&next[index])
        next[index].included = true
        edits = next
    }

    private func stepLoad(_ direction: Int) {
        mutate { draft in
            let next = draft.loadLbs + (Double(direction) * ExerciseEntry.loadStep)
            draft.loadLbs = min(max(next, 0), ExerciseEntry.maxLoad)
        }
        issue = nil
        Haptics.tick()
    }

    private func stepCount(
        _ keyPath: WritableKeyPath<ExerciseEntryDraft, Int>,
        by direction: Int,
        ceiling: Int
    ) {
        mutate { draft in
            draft[keyPath: keyPath] = min(max(draft[keyPath: keyPath] + direction, 1), ceiling)
        }
        issue = nil
        Haptics.tick()
    }

    private func stepHold(_ direction: Int) {
        mutate { draft in
            let next = draft.holdSeconds + (direction * 5)
            draft.holdSeconds = min(max(next, 5), ExerciseEntry.maxHoldSeconds)
        }
        issue = nil
        Haptics.tick()
    }

    private func skip() {
        var next = exercises
        guard next.indices.contains(index) else { return }
        next[index].included = false
        edits = next
        issue = nil
        index += 1
    }

    private func advance() {
        var next = exercises
        guard next.indices.contains(index) else { return }
        next[index].included = true
        edits = next
        if let message = ExerciseEntry.issue(for: next[index]) {
            issue = message
            return
        }
        issue = nil
        index += 1
    }

    private func back() {
        issue = nil
        if index == 0 {
            dismiss()
        } else {
            index -= 1
        }
    }

    private func save() {
        let logs = GuidedSessionDraft.logs(from: exercises)
        guard !logs.isEmpty else {
            dismiss()
            return
        }
        let phase = settingsList.first?.currentPhase ?? .heavySlow
        let day = Calendar.current.startOfDay(for: Date())
        for log in logs {
            let session = TrainingSession(
                date: day,
                phase: phase,
                sessionType: log.sessionType,
                whatIDid: log.whatIDid,
                painDuring: log.painDuring,
                painAfter: PainScore.notLogged,
                resistanceSets: log.sets
            )
            // A finished log is not a 24-hour task. Leave older rows untouched.
            session.response24h = .notApplicable
            modelContext.insert(session)
        }
        do {
            try modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            saveError = "The session could not be saved. Try again."
        }
    }
}
