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
            RootView()
                .preferredColorScheme(.dark)
                .task {
                    let context = ModelContext(container)
                    _ = try? AppBootstrap.ensureSettings(context: context)
                }
        }
        .modelContainer(container)
    }
}
