"use client";

import { useMemo, useState } from "react";
import { localCalendar } from "@/domain/calendar";
import { prescribeToday } from "@/domain/prescription";
import { DECISION_TITLES, RESPONSE_TITLES, SESSION_TYPE_TITLES, type DailyCheckIn, type TrainingSession } from "@/domain/types";
import { useStore } from "@/data/store";
import { CheckInSheet } from "./CheckInSheet";
import { ResolveSheet } from "./ResolveSheet";
import { SessionSheet } from "./SessionSheet";
import { EmptyState, Segmented } from "./ui";

type Filter = "all" | "daily" | "session";

type Row =
  | { kind: "daily"; date: string; checkIn: DailyCheckIn }
  | { kind: "session"; date: string; session: TrainingSession };

export function LogView() {
  const {
    settings,
    checkIns,
    sessions,
    upsertCheckIn,
    saveSession,
    deleteSession,
    resolveSession,
  } = useStore();
  const [filter, setFilter] = useState<Filter>("all");
  const [pastOpen, setPastOpen] = useState(false);
  const [pastDay, setPastDay] = useState(localCalendar.dayKey(new Date()));
  const [editCheck, setEditCheck] = useState<DailyCheckIn | null>(null);
  const [editSession, setEditSession] = useState<TrainingSession | null>(null);
  const [resolveId, setResolveId] = useState<string | null>(null);
  const prescription = prescribeToday({ settings, checkIn: null, sessions });

  const rows = useMemo(() => {
    const list: Row[] = [
      ...checkIns.map((c) => ({ kind: "daily" as const, date: c.dayKey, checkIn: c })),
      ...sessions.map((s) => ({ kind: "session" as const, date: s.date, session: s })),
    ];
    list.sort((a, b) => (a.date > b.date ? -1 : 1));
    if (filter === "daily") return list.filter((r) => r.kind === "daily");
    if (filter === "session") return list.filter((r) => r.kind === "session");
    return list;
  }, [checkIns, sessions, filter]);

  const todayKey = localCalendar.dayKey(new Date());

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="font-display text-2xl tracking-wide">Log</h1>
        <button type="button" className="text-sm text-gold" onClick={() => setPastOpen(true)}>
          Log past day
        </button>
      </div>
      <Segmented<Filter>
        ariaLabel="Filter"
        value={filter}
        onChange={setFilter}
        options={[
          { value: "all", label: "All" },
          { value: "daily", label: "Daily" },
          { value: "session", label: "Sessions" },
        ]}
      />
      {rows.length === 0 ? (
        <EmptyState
          title="Nothing logged yet"
          body="Start with this morning’s pain, or run today’s prescription."
          cta="Go to Today"
          onClick={() => {
            window.location.href = "/";
          }}
        />
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((row) =>
            row.kind === "daily" ? (
              <li key={`d-${row.checkIn.dayKey}`}>
                <button
                  type="button"
                  onClick={() => setEditCheck(row.checkIn)}
                  className="w-full rounded-2xl border border-line bg-surface px-4 py-3 text-left"
                >
                  <p className="text-xs uppercase tracking-[0.14em] text-muted">{row.date} · check-in</p>
                  <p className="mt-1 text-sm text-ink">
                    AM {row.checkIn.restingPainAM ?? "—"} · PM {row.checkIn.dailyPainPM ?? "—"} ·{" "}
                    {row.checkIn.steps ?? "—"} steps
                  </p>
                </button>
              </li>
            ) : (
              <li key={`s-${row.session.id}`}>
                <button
                  type="button"
                  onClick={() =>
                    row.session.response24h === "pending"
                      ? setResolveId(row.session.id)
                      : setEditSession(row.session)
                  }
                  className="w-full rounded-2xl border border-line bg-surface px-4 py-3 text-left"
                >
                  <p className="text-xs uppercase tracking-[0.14em] text-muted">
                    {row.date} · {SESSION_TYPE_TITLES[row.session.sessionType]}
                    {row.session.response24h === "pending"
                      ? " · pending"
                      : ` · ${RESPONSE_TITLES[row.session.response24h]}${
                          row.session.decision ? ` / ${DECISION_TITLES[row.session.decision]}` : ""
                        }`}
                  </p>
                  <p className="mt-1 text-sm text-ink">{row.session.whatIDid}</p>
                </button>
              </li>
            ),
          )}
        </ul>
      )}

      <CheckInSheet
        open={Boolean(editCheck)}
        onClose={() => setEditCheck(null)}
        existing={editCheck}
        phase={settings.currentPhase}
        dayKey={editCheck?.dayKey ?? todayKey}
        onSave={upsertCheckIn}
      />
      <CheckInSheet
        open={pastOpen}
        onClose={() => setPastOpen(false)}
        existing={checkIns.find((c) => c.dayKey === pastDay) ?? null}
        phase={settings.currentPhase}
        dayKey={pastDay}
        onSave={async (row) => {
          await upsertCheckIn(row);
          setPastOpen(false);
        }}
      />
      {pastOpen ? (
        <div className="fixed bottom-24 left-1/2 z-[60] w-[min(92%,24rem)] -translate-x-1/2 rounded-2xl border border-line bg-surface p-3 md:bottom-8">
          <label className="text-xs text-muted">
            Date
            <input
              type="date"
              max={todayKey}
              value={pastDay}
              onChange={(e) => setPastDay(e.target.value)}
              className="mt-1 h-10 w-full rounded-xl bg-surface-2 px-3 text-ink"
            />
          </label>
        </div>
      ) : null}
      <SessionSheet
        open={Boolean(editSession)}
        onClose={() => setEditSession(null)}
        onSave={saveSession}
        onDelete={deleteSession}
        existing={editSession}
        prescription={prescription}
        unit={settings.loadUnit}
        allSessions={sessions}
        phase={editSession?.phase ?? settings.currentPhase}
        todayKey={editSession?.date ?? todayKey}
      />
      <ResolveSheet
        open={Boolean(resolveId)}
        onClose={() => setResolveId(null)}
        session={sessions.find((s) => s.id === resolveId) ?? null}
        allSessions={sessions}
        currentPhase={settings.currentPhase}
        onResolve={resolveSession}
      />
    </div>
  );
}
