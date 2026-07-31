import SwiftUI
import SwiftData
import UserNotifications

@main
struct R3habApp: App {
    private let container: ModelContainer
    @State private var router = AppRouter()

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
        UNUserNotificationCenter.current().delegate = AppServices.shared.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            // IMPORTANT: attach `.modelContainer` to the root *view*, not to
            // `WindowGroup`. Scene-level attachment is a known SwiftData/SwiftUI
            // crash path after long background / background relaunch — see
            // Apple Forums thread 744194 / 761637 and SO 78265564.
            RootView()
                .modelContainer(container)
                .environment(router)
                .preferredColorScheme(.dark)
                .task {
                    AppServices.shared.notificationDelegate.onOpenSession = { [router] id in
                        router.openResolve(sessionId: id)
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // r3hab://resolve?sessionId=<uuid>
        // also accept r3hab://resolve/<uuid>
        guard url.scheme?.lowercased() == "r3hab" else { return }
        let host = url.host?.lowercased() ?? ""
        if host == "resolve" || url.path.contains("resolve") {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let raw = comps.queryItems?.first(where: { $0.name == "sessionId" })?.value,
               let id = UUID(uuidString: raw) {
                router.openResolve(sessionId: id)
                return
            }
            let pathId = url.pathComponents.filter { $0 != "/" }.last ?? ""
            if let id = UUID(uuidString: pathId) {
                router.openResolve(sessionId: id)
            }
        }
    }
}

/// Long-lived app services (notification delegate must not deallocate).
private final class AppServices {
    static let shared = AppServices()
    let notificationDelegate = NotificationDelegate()
}
