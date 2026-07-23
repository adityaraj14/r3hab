import SwiftUI
import SwiftData

/// First-launch onboarding (PR-13). Skippable.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    var onFinished: () -> Void

    @State private var page = 0
    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var wantNotifications = true
    @State private var isBusy = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    purposePage.tag(0)
                    pendingPage.tag(1)
                    phasePage.tag(2)
                    remindersPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: page)

                VStack(spacing: 12) {
                    if page < 3 {
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text(page == 2 ? "Continue" : "Next")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button {
                            Task { await finish(enableNotifications: wantNotifications) }
                        } label: {
                            Text(isBusy ? "Saving…" : "Get started")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isBusy)
                    }

                    Button("Skip for now") {
                        Task { await finish(enableNotifications: false) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .disabled(isBusy)
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                _ = try? AppBootstrap.ensureSettings(context: modelContext)
                if let settings {
                    phase = settings.currentPhase
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var purposePage: some View {
        onboardingCard(
            icon: "figure.strengthtraining.traditional",
            title: "R3hab is your tendon diary",
            body: "Log morning pain, evening pain, steps, and training sessions. Everything stays on this iPhone — offline by design. Notion (or your protocol notes) stays the brain; this app is the daily log."
        )
    }

    private var pendingPage: some View {
        onboardingCard(
            icon: "clock.badge.exclamationmark",
            title: "The 24-hour loop",
            body: "After each training session, answer how the tendon felt the next day: Better, Same, or Worse. That drives Stay / Soft cut / Progress / Hard drop suggestions. Pending items show on Today until you resolve them — never a hard gate on logging."
        )
    }

    private var phasePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Current phase", systemImage: "flag.fill")
                .font(.title2.weight(.bold))
            Text("Pick where you are now. You can change this anytime in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
            Picker("Phase", selection: $phase) {
                ForEach(RehabPhase.allCases) { p in
                    Text(p.title).tag(p)
                }
            }
            .pickerStyle(.inline)
            Text(PhaseGuideCopy.summary(for: phase))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var remindersPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Reminders", systemImage: "bell.badge")
                .font(.title2.weight(.bold))
            Text("Optional local notifications for morning/evening check-ins and overdue 24h responses. You can turn these off anytime. Denying permission still lets you use the full app.")
                .font(.body)
                .foregroundStyle(.secondary)
            Toggle("Enable local reminders", isOn: $wantNotifications)
                .padding(.vertical, 8)
            Text("Default times: 08:00 and 18:30 — adjustable in Settings.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func onboardingCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.bold))
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor
    private func finish(enableNotifications: Bool) async {
        isBusy = true
        defer { isBusy = false }
        let settings = (try? AppBootstrap.ensureSettings(context: modelContext)) ?? settings
        guard let settings else {
            onFinished()
            return
        }
        settings.currentPhase = phase
        settings.hasCompletedOnboarding = true
        settings.notificationsEnabled = enableNotifications
        try? modelContext.save()

        if enableNotifications {
            let granted = await NotificationScheduler.requestAuthorization()
            settings.notificationsEnabled = granted
            try? modelContext.save()
            if granted {
                await NotificationScheduler.reconcile(
                    notificationsEnabled: true,
                    amHour: settings.amReminderHour,
                    amMinute: settings.amReminderMinute,
                    pmHour: settings.pmReminderHour,
                    pmMinute: settings.pmReminderMinute,
                    pendingSessions: []
                )
            }
        }

        Haptics.success()
        onFinished()
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
