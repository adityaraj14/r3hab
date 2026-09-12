import SwiftUI
import SwiftData

/// First-launch onboarding. Five dark screens: name, injury, primary lift, setup, disclaimer.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    var onFinished: () -> Void

    @State private var page = 0
    @State private var phase: RehabPhase = OnboardingCompletion.defaultPhase
    @State private var selectedInjuryID = InjuryCatalog.defaultSelectable.id
    @State private var selectedPrimaryLoadID = PrimaryLoadCatalog.defaultID
    @State private var wantNotifications = false
    @State private var isBusy = false

    private let pageCount = 5
    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        VStack(spacing: 0) {
            pageDots
                .padding(.top, 16)
                .padding(.horizontal, 24)

            TabView(selection: $page) {
                nameStoryPage.tag(0)
                injurySelectPage.tag(1)
                primaryLiftPage.tag(2)
                setupPage.tag(3)
                disclaimerPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                Button {
                    if page < pageCount - 1 {
                        withAnimation { page += 1 }
                    } else {
                        Task {
                            await finish(
                                phase: phase,
                                enableNotifications: wantNotifications,
                                injuryID: selectedInjuryID,
                                primaryLoadID: selectedPrimaryLoadID
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
                            injuryID: selectedInjuryID,
                            primaryLoadID: selectedPrimaryLoadID
                        )
                        await finish(
                            phase: skipped.phase,
                            enableNotifications: skipped.notificationsEnabled,
                            injuryID: skipped.injuryID,
                            primaryLoadID: skipped.primaryLoadID
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
        case 1: return "That's my injury"
        case 2: return selectedTrack == .ql ? "That's my work" : "That's my lift"
        case 4: return "Let's load"
        default: return "Continue"
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? OnboardingTheme.gold : OnboardingTheme.gold.opacity(0.22))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .accessibilityHidden(true)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(page + 1) of \(pageCount)")
    }

    private var nameStoryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: BrandCopy.onboardingEyebrow,
                    title: BrandCopy.onboardingTitle
                )
                Text(BrandCopy.onboardingLead)
                    .font(.body)
                    .foregroundStyle(.secondary)

                privacyPitch

                VStack(spacing: 10) {
                    ForEach(BrandCopy.habits) { habit in
                        habitCard(habit)
                    }
                }

                Text(BrandCopy.onboardingFootnote)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var injurySelectPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: "Injury",
                    title: "What are you loading?"
                )
                Text(BrandCopy.injuryLead)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(InjuryCatalog.selectable) { injury in
                        phaseChoice(
                            title: injury.title,
                            subtitle: injury.subtitle,
                            selected: selectedInjuryID == injury.id
                        ) {
                            selectInjury(injury.id)
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

    private var primaryLiftPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: "Process",
                    title: selectedTrack == .ql ? "Your primary work" : "Your primary lift"
                )
                Text(primaryLiftLead)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(PrimaryLoadCatalog.options(for: selectedTrack)) { option in
                        phaseChoice(
                            title: option.title,
                            subtitle: option.subtitle,
                            selected: selectedPrimaryLoadID == option.id
                        ) {
                            selectedPrimaryLoadID = option.id
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

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            screenHeader(
                eyebrow: "Setup",
                title: "Where are you?"
            )
            Text("Two starting points. You can change phase and lift later in Settings.")
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
                    Text("Morning and evening check-ins, plus overdue 24h pending. Local only — they never leave this phone. Off anytime in Settings.")
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

    private var selectedTrack: RehabTrackID {
        InjuryCatalog.definition(for: selectedInjuryID).protocolTrack
    }

    private var primaryLiftLead: String {
        selectedTrack == .ql ? BrandCopy.qlPrimaryWorkLead : BrandCopy.primaryLiftLead
    }

    private var privacyPitch: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BrandCopy.privacyEyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(OnboardingTheme.gold)

            Text(BrandCopy.privacyTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(BrandCopy.privacyLead)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(BrandCopy.privacyPoints) { point in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.gold)
                        .frame(width: 16)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(point.body)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingTheme.gold.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingTheme.gold.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Private. No ads. On this iPhone.")
    }

    private func selectInjury(_ id: String) {
        selectedInjuryID = id
        let track = InjuryCatalog.definition(for: id).protocolTrack
        if !PrimaryLoadCatalog.contains(selectedPrimaryLoadID, on: track) {
            selectedPrimaryLoadID = PrimaryLoadCatalog.defaultID(for: track)
        }
    }

    private func habitCard(_ habit: BrandHabit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.title)
                .font(.headline)
                .foregroundStyle(OnboardingTheme.gold)
            Text(habit.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
        injuryID: String,
        primaryLoadID: String
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
            injuryID: injuryID,
            primaryLoadID: primaryLoadID
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

/// Applies first-run choices.
/// Skip: Phase B, notifications off. Keep a chosen injury. Page-0 skip still has
/// the catalog default (knee + seated extension). A later skip after picking QL
/// keeps QL and remaps the primary movement onto that track.
enum OnboardingCompletion {
    static let defaultPhase: RehabPhase = .bIsometrics

    static func result(
        skipped: Bool,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        injuryID: String,
        primaryLoadID: String
    ) -> OnboardingChoices {
        let injury = InjuryCatalog.definition(for: injuryID)
        let track = injury.protocolTrack
        let loadID = PrimaryLoadCatalog.normalizedID(primaryLoadID, track: track)
        if skipped {
            return OnboardingChoices(
                phase: defaultPhase,
                notificationsEnabled: false,
                injuryID: injury.id,
                protocolTrack: track,
                primaryLoadID: loadID
            )
        }
        return OnboardingChoices(
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            injuryID: injury.id,
            protocolTrack: track,
            primaryLoadID: loadID
        )
    }

    static func apply(
        to settings: AppSettings,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        injuryID: String,
        primaryLoadID: String
    ) {
        let choices = result(
            skipped: false,
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            injuryID: injuryID,
            primaryLoadID: primaryLoadID
        )
        settings.currentPhase = choices.phase
        settings.hasCompletedOnboarding = true
        settings.notificationsEnabled = choices.notificationsEnabled
        settings.activeTracks = [choices.protocolTrack]
        settings.selectedInjuryID = choices.injuryID
        settings.primaryLoadID = choices.primaryLoadID
    }
}

struct OnboardingChoices: Equatable, Sendable {
    var phase: RehabPhase
    var notificationsEnabled: Bool
    var injuryID: String
    var protocolTrack: RehabTrackID
    var primaryLoadID: String
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
