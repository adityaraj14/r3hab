import SwiftData
import SwiftUI

/// Home is today's step count, the quote, and one way into a session.
/// Nothing asks him to log. Steps stay read-only. Apple Health asks for access
/// once, the first time Home opens. Show stays as a fallback.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var steps = TodayStepsReader()
    @State private var showLogger = false

    private var quote: MotivationalQuote {
        MotivationalQuotes.quote(on: Date())
    }

    var body: some View {
        VStack(spacing: 20) {
            stepsCard
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("“\(quote.text)”")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(AppTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                if let attribution = quote.attribution {
                    Text(attribution)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.quiet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .posterCard(radius: 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home-quote")

            Spacer(minLength: 0)

            Button {
                showLogger = true
            } label: {
                Text("Log a session")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.gold)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("log-session-button")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appCanvas()
        .task {
            #if DEBUG
            await HealthKitStepSeed.seedIfRequested()
            #endif
            await steps.refresh()
            if steps.state == .notAsked {
                await steps.allowAndLoad()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await steps.refresh() }
        }
        .fullScreenCover(isPresented: $showLogger) {
            GuidedSessionFlow()
                .modelContainer(modelContext.container)
                .preferredColorScheme(.dark)
        }
    }

    /// Steps sit at the top in the accent color so he sees them first.
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.subheadline.weight(.bold))
                Text(TodayStepsCopy.title.uppercased())
                    .font(.subheadline.weight(.bold))
                    .tracking(1.2)
            }
            .foregroundStyle(AppTheme.gold)
            Text(TodayStepsCopy.value(steps.state))
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("home-steps-value")
            HStack(alignment: .firstTextBaseline) {
                Text(TodayStepsCopy.detail(steps.state))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if steps.state == .notAsked {
                    Button("Show") {
                        Task { await steps.allowAndLoad() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home-steps-show")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.gold.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppTheme.gold.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-steps")
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
