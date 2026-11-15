import SwiftData
import SwiftUI

/// Three exercises, one screen each. Each exercise is a list of sets he can
/// add, edit, remove, or copy. Skip any he did not do. Save writes one stored
/// session per exercise he kept. Nothing here schedules a reminder.
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

                if let prior = PriorExerciseLookup.latest(kind: draft.kind, in: sessions.map(\.snapshot)) {
                    lastSession(prior)
                }

                if draft.sets.isEmpty {
                    Text("No sets yet. Add one, or skip this exercise.")
                        .font(.body)
                        .foregroundStyle(AppTheme.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(draft.sets.enumerated()), id: \.element.id) { offset, set in
                        setCard(set, number: offset + 1, usesHold: draft.kind.usesHold)
                    }
                }

                HStack(spacing: 12) {
                    Button("Add set") { addSet() }
                        .buttonStyle(.secondaryAction)
                        .disabled(draft.sets.count >= ExerciseEntry.maxCount)
                        .accessibilityIdentifier("guided-add-set")
                    Button("Duplicate last") { duplicateLast() }
                        .buttonStyle(.secondaryAction)
                        .disabled(draft.sets.isEmpty || draft.sets.count >= ExerciseEntry.maxCount)
                        .accessibilityIdentifier("guided-duplicate-set")
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
                        let lines = TrainingLoad.lines(for: log.sets)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.kind.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.ivory)
                            ForEach(lines) { line in
                                Text(line.text)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.quiet)
                            }
                            HStack {
                                Text("Pain \(log.painDuring)")
                                Spacer()
                                if let total = TrainingLoad.summary(
                                    poundReps: lines.reduce(0) { $0 + $1.poundReps },
                                    poundSeconds: lines.reduce(0) { $0 + $1.poundSeconds }
                                ) {
                                    Text(total)
                                        .monospacedDigit()
                                }
                            }
                            .font(.subheadline.weight(.semibold))
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

    private func lastSession(_ prior: PriorExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last session · \(PriorExerciseLookup.dateLabel(day: prior.day, now: Date()))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            ForEach(Array(prior.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
            }
            Button("Copy last session") { copyLastSession(prior) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.gold)
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityIdentifier("guided-copy-last")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided-last-session")
    }

    private func setCard(_ set: LoggedSetDraft, number: Int, usesHold: Bool) -> some View {
        let index = number - 1
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Set \(number)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ivory)
                Spacer()
                Button("Remove") { removeSet(set.id) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)
                    .accessibilityIdentifier("guided-set-\(index)-remove")
            }
            quantityRow(
                title: "Weight",
                value: LoadCopy.labeled(set.loadLbs),
                identifier: "guided-set-\(index)-load"
            ) { stepLoad(set.id, $0) }
            if usesHold {
                quantityRow(
                    title: "Seconds",
                    value: "\(set.holdSeconds)s",
                    identifier: "guided-set-\(index)-seconds"
                ) { stepHold(set.id, $0) }
            } else {
                quantityRow(
                    title: "Reps",
                    value: "\(set.reps)",
                    identifier: "guided-set-\(index)-reps"
                ) { stepReps(set.id, $0) }
            }
        }
        .padding(14)
        .posterCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided-set-\(index)")
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

    private func updateSet(_ id: UUID, _ change: (inout LoggedSetDraft) -> Void) {
        mutate { draft in
            guard let index = draft.sets.firstIndex(where: { $0.id == id }) else { return }
            change(&draft.sets[index])
        }
        issue = nil
        Haptics.tick()
    }

    private func stepLoad(_ id: UUID, _ direction: Int) {
        updateSet(id) { set in
            let next = set.loadLbs + (Double(direction) * ExerciseEntry.loadStep)
            set.loadLbs = min(max(next, 0), ExerciseEntry.maxLoad)
        }
    }

    private func stepReps(_ id: UUID, _ direction: Int) {
        updateSet(id) { set in
            set.reps = min(max(set.reps + direction, 1), ExerciseEntry.maxReps)
        }
    }

    private func stepHold(_ id: UUID, _ direction: Int) {
        updateSet(id) { set in
            let next = set.holdSeconds + (direction * 5)
            set.holdSeconds = min(max(next, 5), ExerciseEntry.maxHoldSeconds)
        }
    }

    private func addSet() {
        var next = exercises
        guard next.indices.contains(index) else { return }
        ExerciseEntry.addSet(to: &next[index])
        next[index].included = true
        edits = next
        issue = nil
        Haptics.tick()
    }

    private func copyLastSession(_ prior: PriorExercise) {
        var next = exercises
        guard next.indices.contains(index) else { return }
        next[index].sets = prior.sets.map {
            LoggedSetDraft(loadLbs: $0.loadLbs, reps: $0.reps, holdSeconds: $0.holdSeconds)
        }
        next[index].included = true
        edits = next
        issue = nil
        Haptics.tick()
    }

    private func duplicateLast() {
        var next = exercises
        guard next.indices.contains(index) else { return }
        ExerciseEntry.duplicateLastSet(in: &next[index])
        next[index].included = true
        edits = next
        issue = nil
        Haptics.tick()
    }

    private func removeSet(_ id: UUID) {
        var next = exercises
        guard next.indices.contains(index) else { return }
        ExerciseEntry.removeSet(id, from: &next[index])
        next[index].included = true
        edits = next
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
