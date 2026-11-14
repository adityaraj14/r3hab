import SwiftData
import SwiftUI

/// Home is the quote and one way into a session. Nothing else asks for a log.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
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
        .fullScreenCover(isPresented: $showLogger) {
            GuidedSessionFlow()
                .modelContainer(modelContext.container)
                .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
