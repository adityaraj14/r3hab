import SwiftUI
import SwiftData

@main
struct R3habApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: DailyCheckIn.self,
                TrainingSession.self,
                AppSettings.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Attach `.modelContainer` to the root view, not to `WindowGroup`.
            // Scene-level attachment is a known SwiftData crash after a long
            // background. RootView flushes before suspension.
            RootView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}
