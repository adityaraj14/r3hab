import SwiftUI

/// The day's prescribed session: dose, tempo, notes, and a log button per exercise.
struct TodaySessionView: View {
    var title: String
    var plan: DayPlan
    var exercises: [PlanExercise]
    var loggedKinds: Set<PlanExerciseKind>
    var onLog: (PlanExercise) -> Void
    var onLogMissed: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text("\(plan.weekLabel) · \(plan.kind.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(plan.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let plyoNote = plan.plyoNote {
                        Text(plyoNote)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                }

                Button("Log missed session", action: onLogMissed)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("log-missed-session-plan")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appCanvas()
        .navigationTitle("Today's session")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("today-session-page")
    }

    private func exerciseRow(_ exercise: PlanExercise) -> some View {
        let recorded = loggedKinds.contains(exercise.id)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if recorded {
                    Text("Recorded")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Text(exercise.doseLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let note = exercise.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Log \(exercise.name)") {
                onLog(exercise)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .accessibilityIdentifier("log-plan-exercise")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
