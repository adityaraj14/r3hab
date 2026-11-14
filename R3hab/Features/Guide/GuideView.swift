import SwiftUI

/// The four rehab stages, condensed from the longer phase notes.
struct GuideView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(RehabGuide.intro)
                        .font(.body)
                        .foregroundStyle(AppTheme.quiet)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(RehabGuide.stages.enumerated()), id: \.element.id) { index, stage in
                        stageCard(number: index + 1, stage: stage)
                    }

                    Text(RehabGuide.caution)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .appCanvas()
            .navigationTitle("Guide")
            .accessibilityIdentifier("guide-screen")
        }
    }

    private func stageCard(number: Int, stage: RehabStage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(number)  \(stage.title)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ivory)
            Text(stage.purpose)
                .font(.subheadline)
                .foregroundStyle(AppTheme.quiet)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(stage.bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .foregroundStyle(AppTheme.gold)
                        Text(bullet)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ivory)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .posterCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    GuideView()
        .preferredColorScheme(.dark)
}
