import SwiftUI

/// Left-to-right wrapping layout for chips. Each subview keeps its ideal size;
/// when a chip would overflow the proposed width it starts a new line.
///
/// Used instead of a horizontal ScrollView inside Form rows, where the row
/// measures scroll content at row width and clips whatever overflows
/// ("Leg pr", "Easy k…"). Wrapping means every label is fully readable and no
/// chip is hidden off the edge.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let frames = layoutFrames(maxWidth: maxWidth, subviews: subviews)
        let contentWidth = frames.map(\.maxX).max() ?? 0
        let contentHeight = frames.map(\.maxY).max() ?? 0
        let width = maxWidth.isFinite ? maxWidth : contentWidth
        return CGSize(width: width, height: contentHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = layoutFrames(maxWidth: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layoutFrames(maxWidth: CGFloat, subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}
