import SwiftUI
import SwiftData

/// Resolve pending 24h response + decision (PR-08).
///
/// Takes a session id, not a model: the row is looked up through `@Query` on
/// the current context every time it is touched, so a sheet left open across a
/// long background never writes through an invalidated `TrainingSession`.
struct Resolve24hSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.date, order: .reverse) private var allSessions: [TrainingSession]

    let sessionId: UUID

    @State private var response: Response24h = .same
    @State private var decision: SessionDecision = .stay
    @State private var showHardDropPhase = false
    @State private var guidance: String?
    @State private var errorMessage: String?
    @State private var loadNudge: LoadNudge?
    @State private var showDecisionChoices = false

    private var settings: AppSettings? { settingsList.first }
    private var session: TrainingSession? {
        allSessions.first { $0.id == sessionId && !$0.isDraft }
    }

    var body: some View {
        NavigationStack {
            if let session {
                form(for: session)
            } else {
                ContentUnavailableView(
                    "Session not found",
                    systemImage: "questionmark.circle",
                    description: Text("This 24h item may have been deleted or already resolved.")
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func form(for session: TrainingSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.displayTitle)
                        .font(.headline)
                    if let resistance = session.resistanceSummary {
                        Text(resistance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(sessionContextLine(session))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .posterCard()

                Text("HOW IS THE TENDON?")
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.quiet)

                ForEach([Response24h.better, .same, .worse], id: \.self) { option in
                    responseCard(option)
                }

                Text(DecisionSuggester.closeLine(for: decision))
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("close-line")
                    .accessibilityLabel(DecisionSuggester.closeLine(for: decision))

                if let guidance {
                    Text(guidance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DisclosureGroup(isExpanded: $showDecisionChoices) {
                    VStack(spacing: 8) {
                        ForEach([SessionDecision.stay, .progress, .softCut, .hardDrop], id: \.self) { choice in
                            Button(choice.title) {
                                decision = choice
                                guidance = DecisionSuggester.guidance(for: choice)
                                Haptics.light()
                            }
                            .buttonStyle(.quietAction)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Choose a different call")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.quiet)
                }
                .tint(AppTheme.quiet)

                Button("Close as rest, no judgment") {
                    closeAsRest()
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.quiet)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .appCanvas()
        .navigationTitle("Resolve 24h")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveClinical() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            if session.response24h == .pending {
                applySuggestion(for: .same)
                response = .same
            } else {
                response = session.response24h == .notApplicable ? .same : session.response24h
                decision = session.decision ?? .stay
                guidance = DecisionSuggester.guidance(for: decision)
            }
        }
        .loadNudgeAlert($loadNudge) {
            loadNudge = nil
            dismiss()
        }
        .sheet(isPresented: $showHardDropPhase) {
            HardDropPhaseSheet(current: settings?.currentPhase ?? .aFlareDeLoad) { chosen in
                if let chosen, let settings {
                    settings.currentPhase = chosen
                    // phaseChangedAt updated by setter
                }
                finalizeSave()
            }
        }
    }

    private func sessionContextLine(_ session: TrainingSession) -> String {
        let date = session.date.formatted(date: .abbreviated, time: .omitted)
        return "\(date) · during \(session.painDuring) → after \(session.displayPainAfter)"
    }

    private func responseCard(_ option: Response24h) -> some View {
        let selected = response == option
        return Button {
            response = option
            applySuggestion(for: option)
            Haptics.light()
        } label: {
            Text(option.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(selected ? AppTheme.gold : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selected ? AppTheme.gold : AppTheme.cardHairline, lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("response-\(option.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func applySuggestion(for response: Response24h) {
        guard let session else { return }
        let priors = DecisionSuggester.priorsForSuggestion(
            current: session.snapshot,
            all: allSessions.map(\.snapshot)
        )
        if let suggested = DecisionSuggester.suggest(response: response, recentResolvedNonRest: priors) {
            decision = suggested
            guidance = DecisionSuggester.guidance(for: suggested)
        } else {
            guidance = nil
        }
    }

    private func saveClinical() {
        errorMessage = nil
        guard response == .better || response == .same || response == .worse else {
            errorMessage = "Pick Better, Same, or Worse."
            return
        }
        if decision == .hardDrop {
            showHardDropPhase = true
            return
        }
        finalizeSave()
    }

    private func finalizeSave() {
        // Re-resolve from the current context at write time.
        guard let session else {
            errorMessage = "This session is no longer available."
            return
        }
        let previousResponse = session.response24h
        session.response24h = response
        session.decision = decision
        session.resolvedAt = Date()
        session.snoozedUntil = nil
        session.updatedAt = Date()
        do {
            try modelContext.save()
            NotificationScheduler.cancelPending(sessionId: session.id)
            Haptics.light()
            let shouldNudge = previousResponse == .pending || previousResponse != response
            if shouldNudge,
               let nudge = LoadNudgeEvaluator.afterResolve(
                    response: response,
                    current: session.snapshot,
                    all: allSessions.map(\.snapshot)
               ) {
                loadNudge = nudge
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func closeAsRest() {
        guard let session else {
            dismiss()
            return
        }
        session.response24h = .notApplicable
        session.decision = .rest
        session.resolvedAt = Date()
        session.snoozedUntil = nil
        session.updatedAt = Date()
        try? modelContext.save()
        NotificationScheduler.cancelPending(sessionId: session.id)
        Haptics.light()
        dismiss()
    }
}

/// Optional phase step-back after HardDrop.
struct HardDropPhaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: RehabPhase
    var onFinish: (RehabPhase?) -> Void

    @State private var selected: RehabPhase = .aFlareDeLoad
    @State private var changePhase = true

    private var earlier: [RehabPhase] {
        let all = RehabPhase.allCases
        guard let idx = all.firstIndex(of: current), idx > 0 else { return [] }
        return Array(all.prefix(idx))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Also change current phase", isOn: $changePhase)
                    if changePhase, !earlier.isEmpty {
                        Picker("New phase", selection: $selected) {
                            ForEach(earlier) { p in
                                Text(p.title).tag(p)
                            }
                        }
                    }
                } footer: {
                    Text("Hard drop means step back when ready. You can keep the phase and only reduce load.")
                }
            }
            .navigationTitle("Hard drop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onFinish(changePhase ? selected : nil)
                        dismiss()
                    }
                }
            }
            .onAppear {
                selected = earlier.last ?? .aFlareDeLoad
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension View {
    func loadNudgeAlert(
        _ nudge: Binding<LoadNudge?>,
        onAcknowledge: @escaping () -> Void
    ) -> some View {
        alert(
            nudge.wrappedValue?.title ?? "Reminder",
            isPresented: Binding(
                get: { nudge.wrappedValue != nil },
                set: { shown in
                    if !shown {
                        onAcknowledge()
                    }
                }
            )
        ) {
            Button("Got it") { onAcknowledge() }
        } message: {
            Text(nudge.wrappedValue?.message ?? "")
        }
    }
}
