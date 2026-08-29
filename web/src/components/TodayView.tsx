"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { localCalendar } from "@/domain/calendar";
import { painSeries } from "@/domain/chartAggregates";
import { overduePending, todayPending } from "@/domain/pendingQueue";
import { evaluatePhaseAExit } from "@/domain/phaseAExit";
import { prescribeToday } from "@/domain/prescription";
import { formatLoad } from "@/domain/nextLoadSuggester";
import {
  checkInToSnapshot,
  sessionToSnapshot,
  settingsToPhaseSnapshot,
  type DailyCheckIn,
  type TrainingSession,
} from "@/domain/types";
import { useStore } from "@/data/store";
import { CheckInSheet } from "./CheckInSheet";
import { MiniSparkline } from "./MiniSparkline";
import { ResolveSheet } from "./ResolveSheet";
import { SessionSheet } from "./SessionSheet";
import { EmptyState, PhaseChip, PrimaryButton } from "./ui";

export function TodayView() {
  const router = useRouter();
  const { settings, checkIns, sessions, upsertCheckIn, saveSession, resolveSession } = useStore();
  const todayKey = localCalendar.dayKey(new Date());
  const todayCheck = checkIns.find((c) => c.dayKey === todayKey) ?? null;
  const snaps = sessions.map(sessionToSnapshot);
  const overdue = overduePending(snaps, new Date());
  const early = todayPending(snaps, new Date());
  const prescription = prescribeToday({ settings, checkIn: todayCheck, sessions });
  const spark = painSeries(checkIns, "restingAM", 7, new Date());
  const phaseA =
    settings.currentPhase === "A"
      ? evaluatePhaseAExit(checkIns.map(checkInToSnapshot), settingsToPhaseSnapshot(settings), new Date())
      : null;

  const [checkOpen, setCheckOpen] = useState(false);
  const [sessionOpen, setSessionOpen] = useState(false);
  const [resolveId, setResolveId] = useState<string | null>(null);
  const resolveTarget = sessions.find((s) => s.id === resolveId) ?? null;

  const pendingSessions = useMemo(() => {
    const ids = new Set([...overdue, ...early].map((s) => s.id));
    return sessions
      .filter((s) => ids.has(s.id))
      .sort((a, b) => (a.date < b.date ? -1 : 1));
  }, [sessions, overdue, early]);

  const amMissing = todayCheck?.restingPainAM == null;

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-5">
      <div className="flex items-center justify-between">
        <PhaseChip phase={settings.currentPhase} />
        <span className="text-xs uppercase tracking-[0.16em] text-muted">{todayKey}</span>
      </div>

      {pendingSessions.length > 0 ? (
        <section className="rounded-3xl border border-hot/40 bg-hot/10 p-4">
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-hot">24h pending</p>
          <ul className="mt-3 flex flex-col gap-2">
            {pendingSessions.map((s) => (
              <li key={s.id} className="flex items-center justify-between gap-3">
                <div>
                  <p className="text-sm text-ink">{s.whatIDid}</p>
                  <p className="text-xs text-muted">{s.date}</p>
                </div>
                <button
                  type="button"
                  className="rounded-full bg-gold px-3 py-1.5 text-xs font-semibold text-black"
                  onClick={() => setResolveId(s.id)}
                >
                  Resolve
                </button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {phaseA ? (
        <p
          className={`rounded-2xl px-4 py-3 text-sm ${
            phaseA.isReadyToAdvance ? "bg-ok/15 text-ok" : "bg-surface text-muted"
          }`}
        >
          {phaseA.message}
        </p>
      ) : null}

      <section className="hero-ring rounded-3xl bg-surface p-5">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-gold">Today’s prescription</p>
        <h1 className="mt-2 font-display text-[32px] leading-none tracking-wide text-ink">
          {prescription.title}
        </h1>
        <p className="mt-3 text-sm leading-6 text-muted">{prescription.subtitle}</p>
        {prescription.loadKgL !== null ? (
          <p className="mt-3 text-sm text-ink">
            L {formatLoad(prescription.loadKgL, settings.loadUnit)}
            {prescription.loadKgR !== null
              ? ` · R ${formatLoad(prescription.loadKgR, settings.loadUnit)}`
              : ""}
            {prescription.sets ? ` · ${prescription.sets} sets` : ""}
            {prescription.holdSeconds ? ` · ${prescription.holdSeconds}s` : ""}
            {prescription.reps ? ` · ${prescription.reps} reps` : ""}
            {prescription.tempo ? ` · ${prescription.tempo}` : ""}
            {` · ${prescription.kneeAngle}°`}
          </p>
        ) : null}
        <p className="mt-3 text-xs leading-5 text-muted">{prescription.rationale}</p>
        {prescription.warnings.map((w) => (
          <p key={w} className="mt-2 text-xs text-amber">
            {w}
          </p>
        ))}
        <div className="mt-5">
          <PrimaryButton onClick={() => setSessionOpen(true)}>{prescription.cta}</PrimaryButton>
        </div>
      </section>

      {amMissing ? (
        <EmptyState
          title="Log this morning"
          body="Resting pain first. Next morning is the source of truth for yesterday’s load."
          cta="Log morning pain"
          onClick={() => setCheckOpen(true)}
        />
      ) : (
        <button
          type="button"
          onClick={() => setCheckOpen(true)}
          className="rounded-2xl border border-line bg-surface px-4 py-3 text-left text-sm text-muted"
        >
          AM {todayCheck?.restingPainAM ?? "—"} · stiffness {todayCheck?.morningStiffness ?? "—"} · PM{" "}
          {todayCheck?.dailyPainPM ?? "missing"} · steps {todayCheck?.steps ?? "missing"}
        </button>
      )}

      <MiniSparkline
        points={spark}
        label="AM pain · 7 days"
        onClick={() => router.push("/progress?explorer=1")}
      />

      <CheckInSheet
        open={checkOpen}
        onClose={() => setCheckOpen(false)}
        existing={todayCheck}
        phase={settings.currentPhase}
        dayKey={todayKey}
        onSave={upsertCheckIn}
      />
      <SessionSheet
        open={sessionOpen}
        onClose={() => setSessionOpen(false)}
        onSave={saveSession}
        existing={null}
        prescription={prescription}
        unit={settings.loadUnit}
        allSessions={sessions}
        phase={settings.currentPhase}
        todayKey={todayKey}
      />
      <ResolveSheet
        open={Boolean(resolveTarget)}
        onClose={() => setResolveId(null)}
        session={resolveTarget}
        allSessions={sessions}
        currentPhase={settings.currentPhase}
        onResolve={resolveSession}
      />
    </div>
  );
}

export type LogTarget = DailyCheckIn | TrainingSession;
