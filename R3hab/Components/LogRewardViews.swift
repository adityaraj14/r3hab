import SwiftUI

/// Front-and-center streak on the Today landing screen.
struct StreakHeroView: View {
    let streak: Int
    let loggedToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.title2)
                    .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: loggedToday && streak > 0)

                Text("\(streak)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 2) {
                    Text(streak == 1 ? "day streak" : "day streak")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var subtitle: String {
        if streak == 0 {
            return "Log today to start your streak"
        }
        if loggedToday {
            return streakSubtitle
        }
        return "Log today to keep it going"
    }

    private var streakSubtitle: String {
        switch streak {
        case 1:
            return "Great start — show up again tomorrow"
        case 2...3:
            return "Building momentum"
        case 4...6:
            return "Consistency beats intensity"
        default:
            return "This is your rehab habit"
        }
    }

    private var accessibilityText: String {
        if streak == 0 {
            return "No logging streak yet. Log today to start."
        }
        if loggedToday {
            return "\(streak) day logging streak. Logged today."
        }
        return "\(streak) day logging streak. Log today to keep it going."
    }
}

/// Immediate positive reinforcement after each log save.
struct LogRewardSheet: View {
    let reward: LogReward
    var onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.6)
                Image(systemName: rewardIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: appeared)
            }

            VStack(spacing: 8) {
                if reward.kind != .sameDayBonus, reward.streak > 0 {
                    Text("\(reward.streak)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(reward.streak == 1 ? "day streak" : "day streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(reward.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(reward.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)

            Spacer()

            Button("Continue") {
                Haptics.light()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
                appeared = true
            }
            Haptics.success()
        }
        .accessibilityElement(children: .contain)
    }

    private var rewardIcon: String {
        switch reward.kind {
        case .streakStarted:
            return "star.fill"
        case .streakContinued:
            return "flame.fill"
        case .sameDayBonus:
            return "checkmark.seal.fill"
        }
    }
}

extension View {
    func logRewardSheet(
        _ reward: Binding<LogReward?>,
        onContinue: @escaping () -> Void
    ) -> some View {
        sheet(item: reward) { item in
            LogRewardSheet(reward: item, onContinue: onContinue)
                .preferredColorScheme(.dark)
        }
    }
}

#Preview("Streak hero") {
    StreakHeroView(streak: 5, loggedToday: true)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Reward sheet") {
    LogRewardSheet(
        reward: LogReward(streak: 3, kind: .streakContinued, focus: .morning),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
