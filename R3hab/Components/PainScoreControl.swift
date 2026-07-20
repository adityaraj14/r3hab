import SwiftUI

/// Large 0–10 integer pain control (REQ-UX-001).
struct PainScoreControl: View {
    let title: String
    @Binding var value: Int?
    var allowsClear: Bool = true

    private let range = 0...10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(value.map(String.init) ?? "—")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color(for: value))
                    .accessibilityLabel("\(title) \(value.map(String.init) ?? "not set")")
            }

            HStack(spacing: 6) {
                ForEach(Array(range), id: \.self) { n in
                    Button {
                        value = n
                    } label: {
                        Text("\(n)")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(value == n ? Color.accentColor : Color(.secondarySystemFill))
                            )
                            .foregroundStyle(value == n ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(n)")
                }
            }

            if allowsClear, value != nil {
                Button("Clear") {
                    value = nil
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, 4)
    }

    private func color(for value: Int?) -> Color {
        guard let value else { return .secondary }
        if value >= 5 { return .red }
        if value >= 3 { return .orange }
        return .primary
    }
}

#Preview {
    struct Host: View {
        @State var v: Int? = 2
        var body: some View {
            Form {
                PainScoreControl(title: "Resting pain AM", value: $v)
            }
        }
    }
    return Host()
}
