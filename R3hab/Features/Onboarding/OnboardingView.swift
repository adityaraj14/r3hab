import SwiftUI
import SwiftData

/// First-launch onboarding. Five dark screens: welcome, injury (knee-only
/// confirmation), primary lift, setup, disclaimer + notifications.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    var onFinished: () -> Void

    @State private var page = 0
    @State private var phase: RehabPhase = OnboardingCompletion.initialPhase
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
                                injuryID: selectedInjuryID,
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
                selectedInjuryID = InjuryCatalog.normalizedID(settings.selectedInjuryID)
                selectedPrimaryLoadID = PrimaryLoadCatalog.normalizedID(
                    settings.primaryLoadID,
                    injuryID: selectedInjuryID
                )
            }
        }
    }

    private var primaryCTATitle: String {
        if isBusy { return "Saving…" }
        switch page {
        case 1: return "That’s my injury"
        case 2: return InjuryCatalog.isQL(selectedInjuryID) ? "That’s what I’ll log" : "That’s my lift"
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
        VStack(alignment: .leading, spacing: 14) {
            screenHeader(
                eyebrow: BrandCopy.onboardingEyebrow,
                title: BrandCopy.onboardingTitle
            )
            Text(BrandCopy.onboardingLead)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            privacyLine

            VStack(spacing: 8) {
                ForEach(BrandCopy.tenets) { tenet in
                    BrandCardRow(card: tenet)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var injuryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: "Injury",
                    title: BrandCopy.injuryTitle
                )

                VStack(spacing: 10) {
                    ForEach(InjuryCatalog.all) { injury in
                        choiceCard(
                            title: injury.title,
                            selected: selectedInjuryID == injury.id
                        ) {
                            selectInjury(injury.id)
                        }
                    }
                }

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
                    title: modalityTitle
                )
                Text(modalityLead)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(PrimaryLoadCatalog.options(for: selectedInjuryID)) { option in
                        choiceCard(
                            title: option.title,
                            selected: selectedPrimaryLoadID == option.id
                        ) {
                            selectedPrimaryLoadID = option.id
                        }
                    }
                }

                Label(BrandCopy.primaryLiftTip, systemImage: "lightbulb")
                    .font(.footnote)
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

    /// Three selectable starting points, explanation on the card itself.
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(BrandCopy.setupTenetFraming)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.quiet)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(BrandCopy.setupPhaseChoices) { choice in
                        choiceCard(
                            title: choice.title,
                            subtitle: choice.body,
                            selected: phase == choice.phase
                        ) {
                            phase = choice.phase
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

    /// Disclaimer, then the notification opt-in, then the final CTA below.
    private var disclaimerPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenHeader(
                    eyebrow: BrandCopy.disclaimerEyebrow,
                    title: BrandCopy.disclaimerTitle
                )
                Text(BrandCopy.disclaimerBody)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                notificationsToggle
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var notificationsToggle: some View {
        Toggle(isOn: $wantNotifications) {
            VStack(alignment: .leading, spacing: 4) {
                Text(BrandCopy.notificationsToggleTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(BrandCopy.notificationsToggleBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppTheme.gold)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.quietStroke, lineWidth: 1)
        )
        .padding(.top, 4)
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

    private var modalityTitle: String {
        InjuryCatalog.isQL(selectedInjuryID) ? "What will you log?" : BrandCopy.primaryLiftTitle
    }

    private var modalityLead: String {
        if InjuryCatalog.isQL(selectedInjuryID) {
            return "Walking, weighted side bends, or hip thrusts. Log what you did. Loads can be refined later."
        }
        return BrandCopy.primaryLiftLead
    }

    private func selectInjury(_ id: String) {
        selectedInjuryID = id
        if !PrimaryLoadCatalog.options(for: id).contains(where: { $0.id == selectedPrimaryLoadID }) {
            selectedPrimaryLoadID = PrimaryLoadCatalog.defaultID(for: id)
        }
    }

    /// One-line privacy card.
    private var privacyLine: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            Text(BrandCopy.privacySummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.quietStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Private. No account, no ads, stored entirely on your iPhone.")
    }

    /// Selectable card. `subtitle` is nil for label-only choices (lifts).
    private func choiceCard(
        title: String,
        subtitle: String? = nil,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

/// Icon, title, one-line body. Tenets on Welcome, benefits in Settings.
struct BrandCardRow: View {
    var card: BrandCard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: card.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(card.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Applies first-run choices. Skip: Phase B, notifications off, keep the
/// chosen injury and modality (unknown ids fall back to that injury’s default).
enum OnboardingCompletion {
    /// Pre-selected card on the Setup page.
    static let initialPhase: RehabPhase = .aFlareDeLoad
    /// Phase applied when the user skips without choosing.
    static let defaultPhase: RehabPhase = .bIsometrics

    static func result(
        skipped: Bool,
        phase: RehabPhase,
        notificationsEnabled: Bool,
        injuryID: String = InjuryCatalog.defaultSelectable.id,
        primaryLoadID: String
    ) -> OnboardingChoices {
        let resolvedInjury = InjuryCatalog.normalizedID(injuryID)
        let loadID = PrimaryLoadCatalog.normalizedID(primaryLoadID, injuryID: resolvedInjury)
        if skipped {
            return OnboardingChoices(
                phase: defaultPhase,
                notificationsEnabled: false,
                injuryID: resolvedInjury,
                primaryLoadID: loadID
            )
        }
        return OnboardingChoices(
            phase: phase,
            notificationsEnabled: notificationsEnabled,
            injuryID: resolvedInjury,
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
        settings.selectedInjuryID = choices.injuryID
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
    var injuryID: String
    var primaryLoadID: String
}

#Preview {
    OnboardingView(onFinished: {})
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
