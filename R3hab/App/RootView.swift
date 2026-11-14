import SwiftUI
import SwiftData
import UIKit

/// Scene shell. Three tabs: Home, Log, Guide. Suspension still flushes SwiftData
/// before the app is frozen so a session saved at the edge of background survives.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootTabs()
            .onChange(of: scenePhase) { _, phase in
                handleScenePhase(phase)
            }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            modelContext.autosaveEnabled = true
        case .inactive, .background:
            modelContext.autosaveEnabled = false
            flushSwiftDataForSuspension()
        @unknown default:
            break
        }
    }

    @MainActor
    private func flushSwiftDataForSuspension() {
        let handle = BackgroundTaskBox()
        handle.id = UIApplication.shared.beginBackgroundTask(withName: "r3hab.swiftdata.flush") {
            handle.end()
        }
        guard handle.id != .invalid else { return }
        defer { handle.end() }
        guard modelContext.hasChanges else { return }
        try? modelContext.save()
    }
}

private struct RootTabs: View {
    @Environment(\.modelContext) private var modelContext
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            SessionLogView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
                .tag(1)
            GuideView()
                .tabItem { Label("Guide", systemImage: "book.fill") }
                .tag(2)
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
        .task {
            if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
                // Onboarding and reminders are gone. Leave the diary rows alone.
                var changed = false
                if !settings.hasCompletedOnboarding {
                    settings.hasCompletedOnboarding = true
                    changed = true
                }
                if settings.notificationsEnabled {
                    settings.notificationsEnabled = false
                    changed = true
                }
                if changed {
                    try? modelContext.save()
                }
            }
            NotificationScheduler.cancelAll()
        }
    }
}

/// Mutable box so the expiration handler can end the same background task id.
private final class BackgroundTaskBox {
    var id: UIBackgroundTaskIdentifier = .invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

#Preview {
    RootView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
