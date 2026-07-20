import SwiftUI

/// Trends tab (named to avoid collision with SwiftUI.ProgressView).
struct RehabProgressView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Progress",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("7- and 28-day charts ship in PR-10.")
            )
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    RehabProgressView()
}
