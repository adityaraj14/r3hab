import SwiftUI

/// Placeholder until Settings + export/import (PR-12).
struct SettingsStubView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("App", value: "R3hab")
                LabeledContent("Protocol", value: "v1")
            }
            Section {
                Text("Export, import, reminders, and phase settings land in PR-12.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Disclaimer") {
                Text("R3hab supports self-managed rehab logging. It is not a medical device and does not replace professional care.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsStubView()
    }
}
