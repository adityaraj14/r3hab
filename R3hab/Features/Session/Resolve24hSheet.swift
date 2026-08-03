import SwiftUI
import SwiftData

/// Resolve pending 24h response + decision (PR-08).
struct Resolve24hSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.date, order: .reverse) private var allSessions: [TrainingSession]

    let session: TrainingSession

    @State private var response: Response24h = .same
    @State private var decision: SessionDecision = .stay
    @State private var showHardDropPhase = false
    @State private var guidance: String?
    @State private var errorMessage: String?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Text(session.whatIDid)
                        .font(.body)
                    LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("During / after", value: "\(session.painDuring) → \(session.painAfter)")
                    if let resistance = session.resistanceSummary {
                        LabeledContent("Resistance", value: resistance)
                    }
                }

                Section("How is the tendon next day?") {
                    Picker("24h response", selection: $response) {
                        Text("Better").tag(Response24h.better)
                        Text("Same").tag(Response24h.same)
                        Text("Worse").tag(Response24h.worse)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: response) { _, new in
                        applySuggestion(for: new)
                    }
                }

                Section("Decision") {
                    Picker("Decision", selection: $decision) {
                        ForEach([SessionDecision.stay, .softCut, .progress, .hardDrop], id: \.self) { d in
                            Text(d.title).tag(d)
                        }
                    }
                    .onChange(of: decision) { _, new in
                        guidance = DecisionSuggester.guidance(for: new)
                    }

                    if let guidance {
                        Text(guidance)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Close as Rest (no 24h judgment)") {
                        closeAsRest()
                    }
                    .foregroundStyle(.orange)
                } footer: {
                    Text("Use Rest if you want to clear this pending without Better/Same/Worse.")
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
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
        .preferredColorScheme(.dark)
    }

    private func applySuggestion(for response: Response24h) {
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
        session.response24h = response
        session.decision = decision
        session.resolvedAt = Date()
        session.snoozedUntil = nil
        session.updatedAt = Date()
        do {
            try modelContext.save()
            NotificationScheduler.cancelPending(sessionId: session.id)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func closeAsRest() {
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
