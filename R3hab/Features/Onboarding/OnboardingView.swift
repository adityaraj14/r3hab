import SwiftUI
import SwiftData

/// First-launch onboarding. Four dark screens; screen 1 is the injury selector.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    var onFinished: () -> Void

    @State private var page = 0
    @State private var phase: RehabPhase = OnboardingCompletion.defaultPhase
    @State private var selectedInjuryID = InjuryCatalog.defaultSelectable.id
    @State private var wantNotifications = false
    @State private var isBusy = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        VStack(spacing: 0) {
            pageDots
                .padding(.top, 16)
                .padding(.horizontal, 24)

            TabView(selection: $page) {
                injurySelectPage.tag(0)
                rule24hPage.tag(1)
                setupPage.tag(2)
                disclaimerPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                Button {
                    if page < 3 {
                        withAnimation { page += 1 }
                    } else {
                        Task {
                        await finish(
                            phase: phase,
                            enableNotifications: wantNotifications,
                            injuryID: selectedInjuryID
                        )
                        }
                    }
                } label: {
                    Text(primaryCTATitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.ink)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(OnboardingTheme.gold)
                .controlSize(.large)
                .disabled(isBusy)

                Button("Skip for now") {
                    Task {
                        let skipped = OnboardingCompletion.result(
                            skipped: true,
                            phase: phase,
                            notificationsEnabled: wantNotifications,
                            injuryID: selectedInjuryID
                        )
                        await finish(
                            phase: skipped.phase,
                            enableNotifications: skipped.notificationsEnabled,
                            injuryID: skipped.injuryID
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.gold.opacity(0.85))
                .disabled(isBusy)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .background(OnboardingTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tint(OnboardingTheme.gold)
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
        }
    }

    private var primaryCTATitle: String {
        if isBusy { return "Saving…" }
        switch page {
        case 0: return "That's my injury"
        case 3: return "Let's load"
        default: return "Continue"
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == page ? OnboardingTheme.gold : OnboardingTheme.gold.opacity(0.22))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .accessibilityHidden(true)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(page + 1) of 4")
    }

    private var injurySelectPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: "Injury",
                    title: "What are you loading?"
                )
                Text("All three use the seated-extension diary and the same knee / patellar tendon protocol. More injuries can land here later.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(InjuryCatalog.selectable) { injury in
                        phaseChoice(
                            title: injury.title,
                            subtitle: injury.subtitle,
                            selected: selectedInjuryID == injury.id
                        ) {
                            selectedInjuryID = injury.id
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var rule24hPage: some View {
        onboardingCard(
            eyebrow: "24h rule",
            title: "Train today. Judge tomorrow.",
            body: "Seated-extension isometrics and HSR. Mild pain during load is OK if the next morning is not worse. Sessions start Pending. Better / Same / Worse drives Stay / Soft cut / Progress."
        )
    }

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            screenHeader(
                eyebrow: "Setup",
                title: "Where are you?"
            )
            Text("Two starting points. You can change phase later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                phaseChoice(
                    title: "Already loading",
                    subtitle: "Phase B · isometrics",
                    selected: phase == .bIsometrics
                ) {
                    phase = .bIsometrics
                }
                phaseChoice(
                    title: "Flare / protect",
                    subtitle: "Phase A · reduce load",
                    selected: phase == .aFlareDeLoad
                ) {
                    phase = .aFlareDeLoad
                }
            }

            Toggle(isOn: $wantNotifications) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local notifications")
                    Text("Morning and evening check-ins, plus overdue 24h pending. Off anytime in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(OnboardingTheme.gold)
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var disclaimerPage: some View {
        onboardingCard(
            eyebrow: "Disclaimer",
            title: "Not a clinic.",
            body: PhaseGuideCopy.medicalDisclaimer
        )
    }

    private func onboardingCard(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            screenHeader(eyebrow: eyebrow, title: title)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func screenHeader(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(OnboardingTheme.gold)
            Text(title)
                .font(.system(size: 34, weight: .heavy, design: .default))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func phaseChoice(
        title: String,
        subtitle: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? OnboardingTheme.gold : .secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? OnboardingTheme.gold : Color.white.opacity(0.08),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @MainActor
    private func finish(
        phase chosenPhase: RehabPhase,
        enableNotifications: Bool,
        injuryID: String
    ) async {
        isBusy = true
        defer { isBusy = false }
        let settings = (try? AppBootstrap.ensureSettings(context: modelContext)) ?? settings
        guard let settings else {
            onFinished()
            return
        }
        OnboardingCompletion.apply(
            to: settings,
            phase: chosenPhase,
            notificationsEnabled: enableNotifications,
            injuryID: injuryID
        )
        try? modelContext.save()

        if enableNotifications {
            let granted = await NotificationScheduler.ensureAuthorizedIfNeeded()
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

/// Applies first-run choices. Skip uses Phase B + notifications off + default injury.
enum OnboardingCompletion {
    static let defaultPhase: RehabPhase = .bIsometrics

    static func result(
        skipped: Bool,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        injuryID: String
    ) -> OnboardingChoices {
        if skipped {
            return OnboardingChoices(
                phase: defaultPhase,
                notificationsEnabled: false,
                injuryID: InjuryCatalog.defaultSelectable.id,
                protocolTrack: InjuryCatalog.defaultSelectable.protocolTrack
            )
        }
        let injury = InjuryCatalog.definition(for: injuryID)
        return OnboardingChoices(
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            injuryID: injury.id,
            protocolTrack: injury.protocolTrack
        )
    }

    static func apply(
        to settings: AppSettings,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        injuryID: String
    ) {
        let choices = result(
            skipped: false,
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            injuryID: injuryID
        )
        settings.currentPhase = choices.phase
        settings.hasCompletedOnboarding = true
        settings.notificationsEnabled = choices.notificationsEnabled
        settings.activeTracks = [choices.protocolTrack]
        settings.selectedInjuryID = choices.injuryID
    }
}

struct OnboardingChoices: Equatable, Sendable {
    var phase: RehabPhase
    var notificationsEnabled: Bool
    var injuryID: String
    var protocolTrack: RehabTrackID
}

private enum OnboardingTheme {
    /// Unstoppable gold on near-black.
    static let gold = Color(red: 0.91, green: 0.73, blue: 0.23)
    static let ink = Color(red: 0.07, green: 0.06, blue: 0.04)
    static let canvas = Color.black
}

#Preview {
    OnboardingView(onFinished: {})
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
