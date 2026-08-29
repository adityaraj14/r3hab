"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { localCalendar } from "@/domain/calendar";
import { painSeries } from "@/domain/chartAggregates";
import { prescribeToday } from "@/domain/prescription";
import { useStore } from "@/data/store";
import { ChartExplorer } from "./ChartExplorer";
import { MiniSparkline } from "./MiniSparkline";
import { ResolveSheet } from "./ResolveSheet";
import { SessionSheet } from "./SessionSheet";
import { EmptyState } from "./ui";

export function ProgressView() {
  const router = useRouter();
  const params = useSearchParams();
  const { settings, checkIns, sessions, saveSession, resolveSession } = useStore();
  const [open, setOpen] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [resolveId, setResolveId] = useState<string | null>(null);

  useEffect(() => {
    if (params.get("explorer") === "1") setOpen(true);
  }, [params]);

  const spark = painSeries(checkIns, "restingAM", 28, new Date());
  const hasData = checkIns.some((c) => c.restingPainAM !== null) || sessions.length > 0;
  const prescription = useMemo(
    () => prescribeToday({ settings, checkIn: null, sessions }),
    [settings, sessions],
  );
  const target = sessions.find((s) => s.id === sessionId) ?? null;

  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-2xl tracking-wide">Progress</h1>
        <button type="button" className="text-sm text-gold" onClick={() => setOpen(true)}>
          Open explorer
        </button>
      </div>
      {!hasData ? (
        <EmptyState
          title="No signal yet"
          body="Log a few mornings and an extension session. Then this becomes a load–response chart you can actually touch."
          cta="Go to Today"
          onClick={() => router.push("/")}
        />
      ) : (
        <MiniSparkline
          points={spark}
          label="AM pain · 28 days"
          onClick={() => setOpen(true)}
        />
      )}
      <p className="text-sm text-muted">
        Dual-axis explorer: AM pain vs seated-extension load (L and R). Brush to zoom. Toggle series.
        Tap a point to open that session.
      </p>
      <ChartExplorer
        open={open}
        onClose={() => {
          setOpen(false);
          if (params.get("explorer") === "1") router.replace("/progress");
        }}
        checkIns={checkIns}
        sessions={sessions}
        unit={settings.loadUnit}
        onSelectDay={(dayKey, sid) => {
          if (sid) {
            const s = sessions.find((x) => x.id === sid);
            if (s?.response24h === "pending") setResolveId(sid);
            else setSessionId(sid);
          } else {
            router.push(`/log`);
          }
          void dayKey;
        }}
      />
      <SessionSheet
        open={Boolean(target)}
        onClose={() => setSessionId(null)}
        onSave={saveSession}
        existing={target}
        prescription={prescription}
        unit={settings.loadUnit}
        allSessions={sessions}
        phase={target?.phase ?? settings.currentPhase}
        todayKey={target?.date ?? localCalendar.dayKey(new Date())}
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
