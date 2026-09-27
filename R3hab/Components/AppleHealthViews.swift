import SwiftUI

/// Apple Health pink/red, used next to the heart glyph.
enum AppleHealthStyle {
    static let heart = Color(red: 1.0, green: 0.18, blue: 0.33)
}

/// "♥ Apple Health" attribution for any place that shows Health data.
struct AppleHealthLabel: View {
    var prefix: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let prefix {
                Text(prefix)
            }
            Image(systemName: "heart.fill")
                .foregroundStyle(AppleHealthStyle.heart)
            Text("Apple Health")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prefix.map { "\($0) " } ?? "")Apple Health")
    }
}

/// Explains Apple Health access before the system prompt appears.
struct AppleHealthPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called after the system prompt closes (granted or not).
    var onFinished: () -> Void = {}

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppleHealthStyle.heart)
                .accessibilityHidden(true)
            Text("Connect Apple Health")
                .font(.title2.weight(.bold))
            Text(HealthKitSteps.permissionExplanation)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await connect() }
            } label: {
                if isRequesting {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.primaryAction)
            .disabled(isRequesting)
            Button("Not now") { dismiss() }
                .buttonStyle(.quietAction)
                .disabled(isRequesting)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("appleHealthPermission")
    }

    @MainActor
    private func connect() async {
        isRequesting = true
        defer { isRequesting = false }
        try? await HealthKitSteps.requestAuthorization()
        dismiss()
        onFinished()
    }
}

#Preview {
    AppleHealthPermissionView()
}
