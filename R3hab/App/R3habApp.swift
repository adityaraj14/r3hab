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
            RootView()
                .environment(router)
                .preferredColorScheme(.dark)
                .task {
                    let context = ModelContext(container)
                    _ = try? AppBootstrap.ensureSettings(context: context)
                    AppServices.shared.notificationDelegate.onOpenSession = { [router] id in
                        router.openResolve(sessionId: id)
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(container)
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
