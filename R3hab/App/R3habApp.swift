import SwiftUI
import SwiftData

@main
struct R3habApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            DailyCheckIn.self,
            TrainingSession.self,
            AppSettings.self
        ])
    }
}
