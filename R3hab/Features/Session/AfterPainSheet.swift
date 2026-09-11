import SwiftUI
import SwiftData

/// Focused after-pain capture — opened from Today, Log, or the 30-minute reminder.
struct AfterPainSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    let session: TrainingSession

    @State private var painAfter: Int?
    @State private var errorMessage: String?
    @State private var errorDismissTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
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
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let painAfter, PainScore.isLogged(painAfter) else {
            presentError("Pain after is required (0–10).")
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
