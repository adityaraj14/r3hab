import SwiftUI
import SwiftData

/// Focused after-pain capture — opened from Today or the 30-minute reminder.
///
/// Takes a session id, not a model; the row is looked up on the current
/// context for display and again at save time.
struct AfterPainSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Query private var sessions: [TrainingSession]

    let sessionId: UUID

    @State private var painAfter: Int?
    @State private var errorMessage: String?
    @State private var errorDismissTask: Task<Void, Never>?

    private var session: TrainingSession? {
        sessions.first { $0.id == sessionId && !$0.isDraft }
    }

    var body: some View {
        NavigationStack {
            if let session {
                form(for: session)
            } else {
                ContentUnavailableView(
                    "Session not found",
                    systemImage: "questionmark.circle",
                    description: Text("This workout may have been deleted.")
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
        Form {
            Section("Session") {
                Text(session.displayTitle)
                    .font(.body.weight(.semibold))
                if let resistance = session.resistanceSummary {
                    Text(resistance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Pain during", value: String(session.painDuring))
            }

            Section {
                PainScoreControl(title: "After (required)", value: $painAfter, allowsClear: false)
            } header: {
                Text("Post-session pain")
            } footer: {
                Text("How the tendon felt once you finished — not the next-morning 24h resolve.")
            }
        }
        .navigationTitle("Pain after")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let errorMessage {
                FormErrorBanner(message: errorMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .onChange(of: painAfter) { _, _ in clearError() }
        .onAppear {
            painAfter = session.loggedPainAfter
        }
    }

    private func save() {
        guard let painAfter, PainScore.isLogged(painAfter) else {
            presentError("Pain after is required (0–10).")
            return
        }
        guard let session else {
            presentError("This session is no longer available.")
            return
        }
        session.painAfter = painAfter
        session.updatedAt = Date()
        do {
            try modelContext.save()
            NotificationScheduler.cancelPainAfter(sessionId: session.id)
            Haptics.success()
            router.requestNotificationSync()
            dismiss()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { errorMessage = nil }
            }
        }
    }

    private func clearError() {
        errorMessage = nil
        errorDismissTask?.cancel()
    }
}
