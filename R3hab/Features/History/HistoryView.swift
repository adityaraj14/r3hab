import SwiftUI

/// Chronological log (daily + sessions). Detail editors land in PR-05/07/09.
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No entries yet",
                systemImage: "calendar",
                description: Text("Your check-ins and sessions will appear here.")
            )
            .navigationTitle("Log")
        }
    }
}

#Preview {
    HistoryView()
}
