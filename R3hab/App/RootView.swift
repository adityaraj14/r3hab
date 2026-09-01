import SwiftUI
import SwiftData
import UIKit

/// Scene-level shell. `@Query` lives in `RootTabContent` so we can remount it
/// after a real background — stale SwiftData instances crash on resume.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var showOnboarding = false
    /// Bumped when leaving the foreground so in-flight notification Tasks stop
    /// touching SwiftData after an `await` (models can be invalid on resume).
    @State private var syncGeneration = 0
    /// True after a real background (not Control Center). Used to remount @Query.
    @State private var didLeaveToBackground = false
    @State private var queryEpoch = 0

    var body: some View {
        RootTabContent(
            showOnboarding: $showOnboarding,
            syncGeneration: syncGeneration
        )
        .id(queryEpoch)
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            modelContext.autosaveEnabled = true
            if didLeaveToBackground {
                didLeaveToBackground = false
                // Fresh @Query after long suspend — stale model instances crash
                // when SwiftUI re-renders the tab shell on resume.
                queryEpoch &+= 1
            }
        case .inactive, .background:
            // Invalidate in-flight syncs *before* they resume across an await
            // and touch models that SwiftData may have dropped.
            syncGeneration &+= 1
            modelContext.autosaveEnabled = false
            if phase == .background {
                didLeaveToBackground = true
            }
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

/// Tab shell + queries. Recreated via `.id` on `RootView` after background.
private struct RootTabContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    @Binding var showOnboarding: Bool
    var syncGeneration: Int

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
            await syncNotifications(generation: syncGeneration)
        }
        .onChange(of: router.notificationSyncToken) { _, _ in
            let generation = syncGeneration
            Task { await syncNotifications(generation: generation) }
        }
        .onChange(of: sessions.count) { _, _ in
            let generation = syncGeneration
            Task { await syncNotifications(generation: generation) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Returning from iOS Settings after granting permission, or any
            // resume that did not remount this view.
            if phase == .active {
                let generation = syncGeneration
                Task { await syncNotifications(generation: generation) }
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

    @MainActor
    private func syncNotifications(generation: Int) async {
        guard generation == syncGeneration else { return }
        let settings: AppSettings
        if let existing = settingsList.first {
            settings = existing
        } else if let seeded = try? AppBootstrap.ensureSettings(context: modelContext) {
            settings = seeded
        } else {
            return
        }
        let snapshot = LogStore.notificationSnapshot(settings: settings, sessions: sessions)
        guard generation == syncGeneration else { return }
        await LogStore.reconcileNotifications(snapshot)
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
