import SwiftData
import SwiftUI

/// TEMPORARY entry on Today (Debug and TestFlight). The Log Workout button still opens SessionEditor.
struct SessionPrototypeMenu: View {
    @Binding var selection: SessionLogPrototypeKind?
    var openStandard: () -> Void

    var body: some View {
        Menu {
            Button("Standard form", action: openStandard)
                .accessibilityIdentifier(SessionPrototypeAccessibility.openStandard)
            ForEach(SessionLogPrototypeKind.allCases) { kind in
                Button(kind.menuTitle) { selection = kind }
                    .accessibilityIdentifier(SessionPrototypeAccessibility.open(kind))
            }
        } label: {
            Text("Prototypes")
                .font(.subheadline.weight(.semibold))
        }
        .tint(AppTheme.quiet)
        .accessibilityIdentifier(SessionPrototypeAccessibility.menu)
        .accessibilityLabel("Log prototypes")
    }
}

extension View {
    /// Toolbar menu plus sheet. Temporary: remove before App Store release.
    func sessionPrototypeEntry(
        selection: Binding<SessionLogPrototypeKind?>,
        date: Date,
        openStandard: @escaping () -> Void
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SessionPrototypeMenu(selection: selection, openStandard: openStandard)
            }
        }
        .sessionPrototypeSheet(selection: selection, date: date)
    }

    func sessionPrototypeSheet(
        selection: Binding<SessionLogPrototypeKind?>,
        date: Date
    ) -> some View {
        sheet(item: selection) { kind in
            NavigationStack {
                SessionPrototypeHost(kind: kind, targetDate: date)
            }
            .tint(AppTheme.gold)
            .preferredColorScheme(.dark)
            // A drag on a ruler must not close the sheet. Use Cancel to close.
            .interactiveDismissDisabled()
        }
    }
}

struct SessionPrototypeHost: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    let kind: SessionLogPrototypeKind
    var targetDate: Date

    @State private var draft: SessionPrototypeDraft
    @State private var didLoad = false
    @State private var errorMessage: String?

    init(kind: SessionLogPrototypeKind, targetDate: Date = Date()) {
        self.kind = kind
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
                stage
            } else {
                AppTheme.canvas
            }
        }
        .navigationTitle(kind.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier(SessionPrototypeAccessibility.cancel)
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
    }

    @ViewBuilder
    private var stage: some View {
        switch kind {
        case .guided:
            GuidedSessionLogView(draft: $draft, spacingWarning: spacingWarning, onSave: save)
        case .live:
            LiveSetTrackerView(draft: $draft, spacingWarning: spacingWarning, onSave: save)
        case .quick:
            QuickSessionLogView(draft: $draft, spacingWarning: spacingWarning, onSave: save)
        }
    }

    private var spacingWarning: String? {
        let snaps = sessions.map(\.snapshot)
        guard SessionSpacing.shouldWarnUnder48h(sessions: snaps, newType: .hsrStrength, now: Date()) else {
            return nil
        }
        return SessionPrototypePlan.under48hWarning
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let phase = settingsList.first?.currentPhase ?? .cHeavySlowResistance
        draft = SessionPrototypePlan.make(
            sessions: sessions.map(\.snapshot),
            phase: phase,
            asOf: Date()
        )
    }

    private func save() {
        do {
            try SessionPrototypeSave.commit(
                draft: draft,
                settings: settingsList.first,
                context: modelContext,
                date: targetDate
            )
            Haptics.success()
            dismiss()
        } catch let error as SessionPrototypeSaveError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Guided") {
    prototypePreview(.guided)
}

#Preview("Live") {
    prototypePreview(.live)
}

#Preview("Quick") {
    prototypePreview(.quick)
}

private func prototypePreview(_ kind: SessionLogPrototypeKind) -> some View {
    NavigationStack {
        SessionPrototypeHost(kind: kind)
    }
    .modelContainer(for: [TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
