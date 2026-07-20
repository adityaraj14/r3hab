import SwiftUI

/// Today dashboard — checklist, CTAs, pending queue (filled in later PRs).
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Phase A · protect, then rebuild")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ContentUnavailableView(
                        "Ready to log",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Daily check-in and training log screens land in the next PRs. This shell is R3hab.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsStubView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
