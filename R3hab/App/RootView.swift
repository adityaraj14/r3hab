import SwiftUI

/// Main tab shell: Today / Log / Progress. Dark mode only.
struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            HistoryView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }

            RehabProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(Color.accentColor)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
