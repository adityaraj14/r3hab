import SwiftData
import SwiftUI

/// Home is the quote, today's step count, and one way into a session.
/// Nothing asks him to log. Steps stay read-only and only request Apple Health
/// when he taps Show.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var steps = TodayStepsReader()
    @State private var showLogger = false

    private var quote: MotivationalQuote {
        MotivationalQuotes.quote(on: Date())
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                Text("“\(quote.text)”")
                    .font(.system(.title, design: .serif))
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

            stepsRow

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
        .task { await steps.refresh() }
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

    private var stepsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(TodayStepsCopy.label(steps.state))
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-steps")
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
