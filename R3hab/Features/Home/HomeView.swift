import SwiftUI
import SwiftData

/// Today dashboard — checklist, CTAs, Phase A banner.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @Query private var settingsList: [AppSettings]

    @State private var showAM = false
    @State private var showPM = false

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: Date()) }

    private var settings: AppSettings? { settingsList.first }

    private var todayCheckIn: DailyCheckIn? {
        let key = DailyCheckIn.dayKey(for: today)
        return checkIns.first { $0.dayKey == key }
    }

    private var phaseAStatus: PhaseAExitStatus? {
        guard let settings, settings.currentPhase == .aFlareDeLoad else { return nil }
        let snaps = checkIns.map(\.snapshot)
        return PhaseAExitEvaluator.evaluate(
            checkIns: snaps,
            settings: settings.phaseSnapshot,
            today: Date(),
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let phaseAStatus {
                        phaseABanner(phaseAStatus)
                    }

                    checklist
                    actions
                    guide
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
            .sheet(isPresented: $showAM) {
                NavigationStack {
                    DailyCheckInEditor(targetDate: today, focusPM: false)
                }
            }
            .sheet(isPresented: $showPM) {
                NavigationStack {
                    DailyCheckInEditor(targetDate: today, focusPM: true)
                }
            }
            .task {
                _ = try? AppBootstrap.ensureSettings(context: modelContext)
            }
        }
    }

    private var header: some View {
        HStack {
            PhaseChip(phase: settings?.currentPhase ?? .aFlareDeLoad)
            Spacer()
            Text(today.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func phaseABanner(_ status: PhaseAExitStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                status.isReadyToAdvance ? "Phase A exit looking good" : "Phase A progress",
                systemImage: status.isReadyToAdvance ? "checkmark.seal.fill" : "flag"
            )
            .font(.subheadline.weight(.semibold))
            Text(status.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(status.isReadyToAdvance ? Color.green.opacity(0.12) : Color(.secondarySystemBackground))
        )
    }

    private var checklist: some View {
        let c = todayCheckIn
        return VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.title3.weight(.semibold))

            checkRow(
                title: "Morning pain",
                done: c?.restingPainAM != nil,
                detail: c?.restingPainAM.map { "\($0)/10" }
            )
            checkRow(
                title: "Evening pain",
                done: c?.dailyPainPM != nil,
                detail: c?.dailyPainPM.map { "\($0)/10" }
            )
            checkRow(
                title: "Steps",
                done: c?.steps != nil,
                detail: c?.steps.map { "\($0)" }
            )
        }
    }

    private func checkRow(title: String, done: Bool, detail: String?) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(title)
            Spacer()
            Text(detail ?? "Missing")
                .foregroundStyle(done ? Color.primary : Color.secondary)
                .font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showAM = true
            } label: {
                Label(
                    todayCheckIn?.restingPainAM == nil ? "Log morning" : "Edit morning",
                    systemImage: "sun.max.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                showPM = true
            } label: {
                Label(
                    todayCheckIn?.dailyPainPM == nil ? "Log evening" : "Edit evening",
                    systemImage: "moon.stars.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This phase")
                .font(.headline)
            Text(PhaseGuideCopy.summary(for: settings?.currentPhase ?? .aFlareDeLoad))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(PhaseGuideCopy.redFlags)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
