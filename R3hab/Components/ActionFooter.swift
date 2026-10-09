import SwiftUI

/// One button in an `ActionFooter`.
struct FooterAction {
    var title: String
    var systemImage: String?
    var identifier: String?
    var isEnabled = true
    var action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        identifier: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// The bottom action bar for a step or a sheet.
/// One action: one full-width lime button.
/// Two actions: two buttons with the same height in one row. The secondary is
/// on the left. The primary is on the right and goes forward.
/// Back is not in the footer. Put it in the navigation bar.
struct ActionFooter: View {
    var secondary: FooterAction?
    var primary: FooterAction

    init(secondary: FooterAction? = nil, primary: FooterAction) {
        self.secondary = secondary
        self.primary = primary
    }

    var body: some View {
        HStack(spacing: 12) {
            if let secondary {
                button(secondary)
                    .buttonStyle(.secondaryAction)
            }
            button(primary)
                .buttonStyle(.primaryAction)
        }
        // Each button takes the height of the taller label.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func button(_ item: FooterAction) -> some View {
        Button(action: item.action) {
            Group {
                if let systemImage = item.systemImage {
                    Label(item.title, systemImage: systemImage)
                } else {
                    Text(item.title)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .disabled(!item.isEnabled)
        .modifier(OptionalIdentifier(identifier: item.identifier))
    }
}

private struct OptionalIdentifier: ViewModifier {
    var identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
