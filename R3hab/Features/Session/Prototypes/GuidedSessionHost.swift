import SwiftData
import SwiftUI

/// Identifies the guided session sheet: a new log or the resume of a draft row.
struct GuidedSessionRequest: Identifiable, Equatable {
    var id = UUID()
    /// Draft row to continue. Nil starts a new log (an open draft for the day is still reused).
    var draftId: UUID?
    var targetDate: Date
}

extension View {
    /// The guided session recorder sheet.
    func guidedSessionSheet(_ request: Binding<GuidedSessionRequest?>) -> some View {
        sheet(item: request) { request in
            NavigationStack {
                GuidedSessionHost(draftId: request.draftId, targetDate: request.targetDate)
            }
            .tint(AppTheme.gold)
            .preferredColorScheme(.dark)
            // A drag on a ruler must not close the sheet. Back on step 1 closes it.
            .interactiveDismissDisabled()
        }
    }
}

/// Records a session one step at a time. Each Next and each Back writes the
/// values and the step to the day's draft row (Today shows it as "In progress").
/// "Save" writes and closes. Back on step 1 writes and closes.
/// Only "Finish session" makes that row a complete session and starts the reminders.
struct GuidedSessionHost: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    var draftId: UUID?
    var targetDate: Date

    @State private var draft: SessionPrototypeDraft
    @State private var stepIndex = 0
    /// The first unfinished step. The draft row stores it, so a resume opens there.
    @State private var furthestStep = 0
    @State private var didLoad = false
    @State private var errorMessage: String?
    /// The draft row this sheet writes to. Set on load or on the first draft save.
    @State private var rowId: UUID?
    /// Values and step at load or at the last draft save.
    @State private var savedDraft: SessionPrototypeDraft?
    @State private var savedStep = 0
    /// Blocks a second Save tap while the first write runs.
    @State private var isSaving = false

    init(draftId: UUID? = nil, targetDate: Date = Date()) {
        self.draftId = draftId
        self.targetDate = targetDate
        _draft = State(initialValue: SessionPrototypePlan.make(
            sessions: [],
            phase: .cHeavySlowResistance,
            asOf: targetDate
        ))
    }

    var body: some View {
        Group {
            if didLoad {
                GuidedSessionLogView(
                    draft: $draft,
                    index: $stepIndex,
                    furthest: $furthestStep,
                    spacingWarning: spacingWarning,
                    onSave: save,
                    onCheckpointSave: {
                        guard GuidedCheckpointing.shouldAutosaveOnRecord(changedSinceSave: changedSinceSave) else { return }
                        saveDraft(closeAfter: false)
                    },
                    onClose: closeFromFirstStep
                )
            } else {
                AppTheme.canvas
            }
        }
        .navigationTitle("Record session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The step view puts Back on the leading side. Save keeps the progress and closes.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveDraft(closeAfter: true) }
                    .disabled(!didLoad)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.saveDraft)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let errorMessage {
                FormErrorBanner(message: errorMessage)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .onAppear(perform: load)
        .onChange(of: draft) { _, _ in
            errorMessage = nil
        }
        .onChange(of: scenePhase) { _, phase in
            autosave(leavingForeground: phase != .active)
        }
    }

    private var spacingWarning: String? {
        let snaps = sessions.filter { $0.id != rowId }.map(\.snapshot)
        guard SessionSpacing.shouldWarnUnder48h(sessions: snaps, newType: .hsrStrength, now: Date()) else {
            return nil
        }
        return SessionPrototypePlan.under48hWarning
    }

    private var changedSinceSave: Bool {
        draft != savedDraft || furthestStep != savedStep
    }

    /// Back on step 1: save the draft and close. With nothing entered and no draft row, close only.
    private func closeFromFirstStep() {
        if GuidedCheckpointing.savesDraftOnClose(rowExists: rowId != nil, changedSinceSave: changedSinceSave) {
            saveDraft(closeAfter: true)
        } else {
            dismiss()
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let phase = settingsList.first?.currentPhase ?? .cHeavySlowResistance
        let others = sessions.filter { $0.id != draftId }.map(\.snapshot)
        let plan = SessionPrototypePlan.make(sessions: others, phase: phase, asOf: Date())
        let resumeId = draftId ?? SessionDraft.openDraftID(
            in: sessions.map(\.snapshot),
            on: targetDate,
            preferring: .hsrStrength
        )
        if let resumeId, let row = sessions.first(where: { $0.id == resumeId && $0.isDraft }) {
            let restored = GuidedCheckpointing.restore(GuidedSessionStore.checkpoint(of: row), onto: plan)
            draft = restored.draft
            stepIndex = restored.stepIndex
            furthestStep = restored.stepIndex
            rowId = row.id
        } else {
            draft = plan
            stepIndex = 0
            furthestStep = 0
            rowId = nil
        }
        savedDraft = draft
        savedStep = furthestStep
    }

    private func saveDraft(closeAfter: Bool) {
        do {
            rowId = try GuidedSessionStore.saveDraft(
                draft: draft,
                stepIndex: furthestStep,
                draftId: rowId,
                context: modelContext,
                date: targetDate
            )
            savedDraft = draft
            savedStep = furthestStep
            if closeAfter {
                Haptics.light()
                dismiss()
            }
        } catch let error as GuidedSaveError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The app goes to the background: keep the step and the values.
    private func autosave(leavingForeground: Bool) {
        guard didLoad else { return }
        guard GuidedCheckpointing.shouldAutosave(
            leavingForeground: leavingForeground,
            changedSinceSave: changedSinceSave
        ) else { return }
        saveDraft(closeAfter: false)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try GuidedSessionStore.commit(
                draft: draft,
                draftId: rowId,
                settings: settingsList.first,
                context: modelContext,
                date: targetDate
            )
            Haptics.success()
            dismiss()
        } catch let error as GuidedSaveError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Guided") {
    NavigationStack {
        GuidedSessionHost()
    }
    .modelContainer(for: [TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
