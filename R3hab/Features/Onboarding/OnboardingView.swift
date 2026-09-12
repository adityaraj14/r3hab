import SwiftUI
import SwiftData

/// First-launch onboarding. Five dark screens: welcome, injury, primary lift, setup, disclaimer.
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
                    track: settings.protocolTrack
                )
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
        case 2: return selectedTrack == .ql ? "That’s my work" : "That’s my lift"
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

    /// Sized to fit above Continue on a 6.1" phone: short lead, one compact
    /// privacy card, three benefit rows. ScrollView stays only as a fallback
    /// for large Dynamic Type.
    private var nameStoryPage: some View {
        ScrollView {
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

                VStack(spacing: 8) {
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
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    private var injurySelectPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenHeader(
                    eyebrow: "Injury",
                    title: BrandCopy.injuryTitle
                )
                Text(BrandCopy.injuryLead)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text(BrandCopy.injuryDiagnosisNote)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(InjuryCatalog.selectable) { injury in
                        phaseChoice(
                            title: injury.title,
                            subtitle: injury.subtitle,
                            selected: InjuryCatalog.normalizedID(selectedInjuryID) == injury.id
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
                    eyebrow: selectedTrack == .ql ? "Work" : "Lift",
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

    private var selectedTrack: RehabTrackID {
        InjuryCatalog.definition(for: selectedInjuryID).protocolTrack
    }

    private var primaryLiftLead: String {
        selectedTrack == .ql ? BrandCopy.qlPrimaryWorkLead : BrandCopy.primaryLiftLead
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

    private func selectInjury(_ id: String) {
        selectedInjuryID = id
        let track = InjuryCatalog.definition(for: id).protocolTrack
        if !PrimaryLoadCatalog.contains(selectedPrimaryLoadID, on: track) {
            selectedPrimaryLoadID = PrimaryLoadCatalog.defaultID(for: track)
        }
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
                    .lineLimit(2)
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
    var protocolTrack: RehabTrackID
    var primaryLoadID: String
}

#Preview {
    OnboardingView(onFinished: {})
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
