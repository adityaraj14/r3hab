import SwiftUI
import SwiftData

/// First-launch onboarding. Five dark screens: welcome, injury (knee-only
/// confirmation), primary lift, setup, disclaimer.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    var onFinished: () -> Void

    @State private var page = 0
    @State private var phase: RehabPhase = OnboardingCompletion.defaultPhase
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
                injuryPage.tag(1)
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
                                primaryLoadID: selectedPrimaryLoadID
                            )
                        }
                    }
                } label: {
                    Text(primaryCTATitle)
                }
                .buttonStyle(.primaryAction)
                .disabled(isBusy)

                Button("Skip for now") {
                    Task {
                        let skipped = OnboardingCompletion.result(
                            skipped: true,
                            phase: phase,
                            notificationsEnabled: wantNotifications,
                            primaryLoadID: selectedPrimaryLoadID
                        )
                        await finish(
                            phase: skipped.phase,
                            enableNotifications: skipped.notificationsEnabled,
                            primaryLoadID: skipped.primaryLoadID
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .disabled(isBusy)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .appCanvas()
        .preferredColorScheme(.dark)
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
            if let settings {
                selectedPrimaryLoadID = PrimaryLoadCatalog.normalizedID(settings.primaryLoadID)
                if settings.currentPhase == .aFlareDeLoad {
                    phase = .aFlareDeLoad
                }
            }
        }
    }

    private var primaryCTATitle: String {
        if isBusy { return "Saving…" }
        switch page {
        case 1: return "That’s my injury"
        case 2: return "That’s my lift"
        case 4: return "Let’s load"
        default: return "Continue"
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.white : Color.white.opacity(0.22))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .accessibilityHidden(true)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(page + 1) of \(pageCount)")
    }

    /// Laid out to fit above Continue, not to scroll: `ViewThatFits` takes the
    /// plain stack when the page has room (6.1" and up at default text size)
    /// and only falls back to a ScrollView for small phones / large Dynamic
    /// Type. Every line uses `fixedSize` so text wraps instead of truncating.
    private var nameStoryPage: some View {
        ViewThatFits(in: .vertical) {
            welcomeContent
            ScrollView {
                welcomeContent
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            screenHeader(
                eyebrow: BrandCopy.onboardingEyebrow,
                title: BrandCopy.onboardingTitle
            )
            Text(BrandCopy.onboardingLead)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            privacyPitch

            VStack(spacing: 10) {
                ForEach(BrandCopy.habits) { habit in
                    habitRow(habit)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// One injury ships, so this page confirms rather than picks: what the
    /// protocol covers, the diagnosis note, and the single knee card.
    private var injuryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: "Injury",
                    title: BrandCopy.injuryTitle
                )
                Text(BrandCopy.injuryLead)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                injuryCard(InjuryCatalog.patellarTendinopathy)

                Text(BrandCopy.injuryDiagnosisNote)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    eyebrow: "Lift",
                    title: "Your primary lift"
                )
                Text(BrandCopy.primaryLiftLead)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(PrimaryLoadCatalog.all) { option in
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: BrandCopy.setupEyebrow,
                    title: BrandCopy.setupTitle
                )
                Text(BrandCopy.setupLead)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(BrandCopy.setupPhaseLines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(line.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(spacing: 10) {
                    phaseChoice(
                        title: "Flare / protect",
                        subtitle: "Phase A · reduce load",
                        selected: phase == .aFlareDeLoad
                    ) {
                        phase = .aFlareDeLoad
                    }
                    phaseChoice(
                        title: "Already loading",
                        subtitle: "Phase B · isometrics",
                        selected: phase == .bIsometrics
                    ) {
                        phase = .bIsometrics
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
                .tint(AppTheme.gold)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var disclaimerPage: some View {
        onboardingCard(
            eyebrow: BrandCopy.disclaimerEyebrow,
            title: BrandCopy.disclaimerTitle,
            body: BrandCopy.disclaimerBody
        )
    }

    private func onboardingCard(eyebrow: String, title: String, body: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenHeader(eyebrow: eyebrow, title: title)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private func screenHeader(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.quiet)
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .default))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func injuryCard(_ injury: InjuryDefinition) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: InjuryCatalog.systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.quiet)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(injury.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(injury.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.quietStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Compact privacy card: one title, one summary line, three short points.
    private var privacyPitch: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
                Text(BrandCopy.privacyTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text(BrandCopy.privacySummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(BrandCopy.privacyPoints) { point in
                Text(point.body)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.quietStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Private. No account, no ads, stored on this iPhone only.")
    }


    private func habitRow(_ habit: BrandHabit) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: habitIcon(habit))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(habit.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func habitIcon(_ habit: BrandHabit) -> String {
        switch habit.title {
        case "Track the journey": return "chart.line.uptrend.xyaxis"
        case "Stay accountable": return "checkmark.circle"
        default: return "scalemass"
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
                    .foregroundStyle(selected ? Color.white : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? Color.white.opacity(0.7) : Color.white.opacity(0.08),
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

/// Applies first-run choices. Knee-only: the injury is always patellar
/// tendinopathy. Skip: Phase B, notifications off, keep the chosen lift
/// (unknown / retired ids fall back to seated extension).
enum OnboardingCompletion {
    static let defaultPhase: RehabPhase = .bIsometrics

    static func result(
        skipped: Bool,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        primaryLoadID: String
    ) -> OnboardingChoices {
        let loadID = PrimaryLoadCatalog.normalizedID(primaryLoadID)
        if skipped {
            return OnboardingChoices(
                phase: defaultPhase,
                notificationsEnabled: false,
                primaryLoadID: loadID
            )
        }
        return OnboardingChoices(
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            primaryLoadID: loadID
        )
    }

    static func apply(
        to settings: AppSettings,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        primaryLoadID: String
    ) {
        let choices = result(
            skipped: false,
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            primaryLoadID: primaryLoadID
        )
        settings.currentPhase = choices.phase
        settings.hasCompletedOnboarding = true
        settings.notificationsEnabled = choices.notificationsEnabled
        settings.selectedInjuryID = InjuryCatalog.defaultSelectable.id
        settings.primaryLoadID = choices.primaryLoadID
    }
}

/// TEMPORARY TestFlight helper. Remove before App Store / public release.
enum OnboardingReset {
    static func reopenGate(on settings: AppSettings) {
        settings.hasCompletedOnboarding = false
    }
}

struct OnboardingChoices: Equatable, Sendable {
    var phase: RehabPhase
    var notificationsEnabled: Bool
    var primaryLoadID: String
}

#Preview {
    OnboardingView(onFinished: {})
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
