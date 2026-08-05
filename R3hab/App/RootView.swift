import SwiftUI
import SwiftData
import UIKit

/// Main tab shell: Today / Log / Progress. Dark mode only. Onboarding gate (PR-13).
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    @State private var showOnboarding = false

    private var settings: AppSettings? { settingsList.first }

    private var overdueBadge: Int {
        PendingQueue.overdue(sessions: sessions.map(\.snapshot), now: Date()).count
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(0)
                .badge(overdueBadge > 0 ? overdueBadge : 0)

            HistoryView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            RehabProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
        }
        .tint(Color.accentColor)
        .preferredColorScheme(.dark)
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
            if let settings, !settings.hasCompletedOnboarding {
                showOnboarding = true
            }
            await syncNotifications()
        }
        .onChange(of: router.notificationSyncToken) { _, _ in
            Task { await syncNotifications() }
        }
        .onChange(of: sessions.count) { _, _ in
            Task { await syncNotifications() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Finish SwiftData work under a background task before suspension.
            // Holding a SQLite lock across suspend → OS SIGKILL 0xdead10cc
            // ("dead lock"), which users see as “the app crashed” hours later.
            if phase == .background {
                flushSwiftDataForSuspension()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
                router.requestNotificationSync()
            }
        }
        .sheet(isPresented: Binding(
            get: { router.resolveSessionId != nil },
            set: { if !$0 { router.resolveSessionId = nil } }
        )) {
            if let id = router.resolveSessionId,
               let session = sessions.first(where: { $0.id == id }) {
                Resolve24hSheet(session: session)
            } else {
                NavigationStack {
                    ContentUnavailableView(
                        "Session not found",
                        systemImage: "questionmark.circle",
                        description: Text("This 24h item may have been deleted or already resolved.")
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { router.resolveSessionId = nil }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    private func syncNotifications() async {
        guard let settings = try? AppBootstrap.ensureSettings(context: modelContext) else { return }
        await LogStore.reconcileNotifications(settings: settings, sessions: sessions)
    }

    @MainActor
    private func flushSwiftDataForSuspension() {
        let handle = BackgroundTaskBox()
        handle.id = UIApplication.shared.beginBackgroundTask(withName: "r3hab.swiftdata.flush") {
            handle.end()
        }
        guard handle.id != .invalid else { return }
        defer { handle.end() }
        try? modelContext.save()
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
        .environment(AppRouter())
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
