import SwiftUI
import SwiftData

/// Pick a planned session and the day it was actually done.
struct MissedSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]

    @State private var selectedSlot: Date?
    @State private var performedDate = Calendar.current.startOfDay(for: Date())
    @State private var makeupLog: MakeupLog?
    @State private var pendingLink: PendingLink?

    private var calendar: Calendar { .current }
    private var settings: AppSettings? { settingsList.first }

    private var programStart: Date {
        let stored = settings?.programStartDate ?? Date()
        return TwelveWeekPlan.isUnsetStart(stored) ? Date() : stored
    }

    private var overrides: [PlanSessionOverride] {
        settings?.planOverrides ?? []
    }

    private var sessionSnaps: [TrainingSessionSnapshot] {
        sessions.map(\.snapshot)
    }

    private var slots: [PlannedSession] {
        PlanSchedule.loggableSlots(
            start: programStart,
            on: Date(),
            sessions: sessionSnaps,
            overrides: overrides,
            calendar: calendar
        )
    }

    private var performedRange: ClosedRange<Date> {
        let end = Date()
        return min(programStart, end)...end
    }

    private var spacingWarning: String? {
        guard let last = PlanSchedule.lastAnchor(
            before: performedDate,
            sessions: sessionSnaps,
            overrides: overrides,
            calendar: calendar
        ) else { return nil }
        let gap = SessionSpacing.calendarDays(from: last, to: performedDate, calendar: calendar)
        guard gap < SessionSpacing.hardCadenceDays else { return nil }
        return "This is sooner than two days after the last heavy session. The next session will move to keep that rest."
    }

    var body: some View {
        NavigationStack {
            Form {
                if slots.isEmpty {
                    Text("Every planned session through today is already logged.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Planned session", selection: $selectedSlot) {
                        ForEach(slots) { slot in
                            Text(PlanSchedule.slotLabel(slot, calendar: calendar))
                                .tag(Optional(slot.scheduledDate))
                        }
                    }
                    DatePicker(
                        "Done on",
                        selection: $performedDate,
                        in: performedRange,
                        displayedComponents: .date
                    )
                    if let spacingWarning {
                        Text(spacingWarning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !overrides.isEmpty {
                    Section("Make-ups") {
                        ForEach(overrides) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(overrideLine(item))
                                    .font(.subheadline)
                                Button("Remove override", role: .destructive) {
                                    remove(item)
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log missed session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log session") { logSelected() }
                        .fontWeight(.semibold)
                        .disabled(selectedSlot == nil || slots.isEmpty)
                }
            }
            .onAppear(perform: selectDefaultSlot)
            .onChange(of: slots.map(\.scheduledDate)) { _, _ in
                selectDefaultSlot()
            }
            .sheet(item: $makeupLog, onDismiss: linkLoggedSession) { log in
                NavigationStack {
                    SessionEditor(
                        targetDate: log.date,
                        focus: .kneeResistance,
                        initialPresetID: log.presetID
                    )
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
        }
    }

    private func selectDefaultSlot() {
        if let selected = selectedSlot, slots.contains(where: { $0.scheduledDate == selected }) {
            return
        }
        selectedSlot = slots.last?.scheduledDate
    }

    private func logSelected() {
        guard let settings, let scheduled = selectedSlot else { return }
        let performed = calendar.startOfDay(for: performedDate)
        let planned = calendar.startOfDay(for: scheduled)
        let preset = presetID(for: planned)
        var overrideID: UUID?
        if performed != planned {
            let item = PlanSessionOverride(scheduledDate: planned, performedDate: performed)
            settings.planOverrides = PlanOverrideStore.upsert(item, into: settings.planOverrides)
            try? modelContext.save()
            overrideID = item.id
            pendingLink = PendingLink(overrideID: item.id, date: performed)
        }
        makeupLog = MakeupLog(date: performed, presetID: preset, overrideID: overrideID)
    }

    private func remove(_ item: PlanSessionOverride) {
        guard let settings else { return }
        settings.planOverrides = PlanOverrideStore.removing(id: item.id, from: settings.planOverrides)
        try? modelContext.save()
        Haptics.light()
    }

    private func linkLoggedSession() {
        guard let pending = pendingLink, let settings else { return }
        pendingLink = nil
        guard var item = settings.planOverrides.first(where: { $0.id == pending.overrideID }) else { return }
        guard let session = sessions.first(where: {
            $0.isComplete && calendar.isDate($0.date, inSameDayAs: pending.date)
        }) else { return }
        item.sessionID = session.id
        settings.planOverrides = PlanOverrideStore.upsert(item, into: settings.planOverrides)
        try? modelContext.save()
    }

    private func presetID(for scheduled: Date) -> String {
        let plan = TwelveWeekPlan.dayPlan(
            start: programStart,
            on: scheduled,
            sessions: sessionSnaps,
            checkIns: checkIns.map(\.snapshot),
            calendar: calendar
        )
        let exercise = plan.exercises.first { $0.logsWeight && !$0.isWarmup } ?? plan.dailyIsometric
        return exercise.presetID
    }

    private func overrideLine(_ item: PlanSessionOverride) -> String {
        let planned = PlanSchedule.weekdayName(item.scheduledDate, calendar: calendar)
        let done = PlanSchedule.weekdayName(item.performedDate, calendar: calendar)
        return "\(planned) done on \(done)"
    }
}

private struct MakeupLog: Identifiable {
    var id = UUID()
    var date: Date
    var presetID: String
    var overrideID: UUID?
}

private struct PendingLink {
    var overrideID: UUID
    var date: Date
}
