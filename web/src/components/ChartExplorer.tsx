"use client";

import { useMemo, useState } from "react";
import {
  Brush,
  CartesianGrid,
  ComposedChart,
  Legend,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  dayCountForRange,
  loadSeriesBySide,
  painSeries,
  volumeSeries,
  type DayValue,
} from "@/domain/chartAggregates";
import { localCalendar } from "@/domain/calendar";
import { formatLoad } from "@/domain/nextLoadSuggester";
import type { DailyCheckIn, LoadUnit, TrainingSession } from "@/domain/types";

type Range = "7d" | "28d" | "90d" | "all";
type SeriesKey = "am" | "loadL" | "loadR" | "volume";

type ChartRow = {
  dayKey: string;
  label: string;
  am: number | null;
  loadL: number | null;
  loadR: number | null;
  volume: number | null;
};

function labelFor(dayKey: string): string {
  const [, m, d] = dayKey.split("-");
  return `${Number(m)}/${Number(d)}`;
}

function merge(
  am: DayValue[],
  loadL: DayValue[],
  loadR: DayValue[],
  volume: DayValue[],
): ChartRow[] {
  return am.map((row, i) => ({
    dayKey: row.dayKey,
    label: labelFor(row.dayKey),
    am: row.value,
    loadL: loadL[i]?.value ?? null,
    loadR: loadR[i]?.value ?? null,
    volume: volume[i]?.value ?? null,
  }));
}

export function ChartExplorer({
  open,
  onClose,
  checkIns,
  sessions,
  unit,
  onSelectDay,
}: {
  open: boolean;
  onClose: () => void;
  checkIns: DailyCheckIn[];
  sessions: TrainingSession[];
  unit: LoadUnit;
  onSelectDay: (dayKey: string, sessionId: string | null) => void;
}) {
  const [range, setRange] = useState<Range>("28d");
  const [on, setOn] = useState<Record<SeriesKey, boolean>>({
    am: true,
    loadL: true,
    loadR: true,
    volume: false,
  });
  const today = new Date();
  const earliest = [...checkIns.map((c) => c.dayKey), ...sessions.map((s) => s.date)].sort()[0] ?? null;
  const count = dayCountForRange(range, earliest, today, localCalendar);

  const data = useMemo(() => {
    const am = painSeries(checkIns, "restingAM", count, today, localCalendar);
    const loadL = loadSeriesBySide(sessions, "L", count, today, localCalendar);
    const loadR = loadSeriesBySide(sessions, "R", count, today, localCalendar);
    const volume = volumeSeries(sessions, count, today, localCalendar);
    return merge(am, loadL, loadR, volume);
  }, [checkIns, sessions, count, today]);

  const sessionByDay = useMemo(() => {
    const map = new Map<string, string>();
    for (const s of [...sessions].sort((a, b) => (a.createdAt > b.createdAt ? -1 : 1))) {
      if (!map.has(s.date)) map.set(s.date, s.id);
    }
    return map;
  }, [sessions]);

  if (!open) return null;

  const toggle = (key: SeriesKey) => setOn((prev) => ({ ...prev, [key]: !prev[key] }));

  return (
    <div className="fixed inset-0 z-40 flex flex-col bg-bg">
      <div className="flex items-center justify-between px-4 py-3">
        <h2 className="font-display text-lg tracking-wide">Progress</h2>
        <button type="button" className="text-sm text-gold" onClick={onClose}>
          Close
        </button>
      </div>
      <div className="flex gap-2 overflow-x-auto px-4 pb-3">
        {(["7d", "28d", "90d", "all"] as const).map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => setRange(r)}
            className={`h-9 shrink-0 rounded-full px-3 text-xs font-semibold uppercase tracking-[0.14em] ${
              range === r ? "bg-gold text-black" : "border border-line text-muted"
            }`}
          >
            {r}
          </button>
        ))}
      </div>
      <div className="flex flex-wrap gap-2 px-4 pb-2">
        {(
          [
            ["am", "AM pain"],
            ["loadL", "Load L"],
            ["loadR", "Load R"],
            ["volume", "Volume"],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => toggle(key)}
            className={`h-8 rounded-full px-3 text-xs font-semibold ${
              on[key] ? "bg-surface-2 text-gold" : "text-muted line-through"
            }`}
          >
            {label}
          </button>
        ))}
      </div>
      <p className="px-4 pb-2 text-xs text-muted">
        Drag the brush to zoom. Tap a point to open that day. Dual axis: pain 0–10 vs machine load ({unit}).
      </p>
      <div className="min-h-0 flex-1 px-1 pb-6">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart
            data={data}
            margin={{ top: 8, right: 12, left: 0, bottom: 8 }}
            onClick={(state) => {
              const label = state.activeLabel;
              if (label === undefined || label === null) return;
              const key = String(label);
              const row = data.find((r) => r.label === key || r.dayKey === key);
              const dayKey = row?.dayKey;
              if (!dayKey) return;
              onSelectDay(dayKey, sessionByDay.get(dayKey) ?? null);
            }}
          >
            <CartesianGrid stroke="#2a2a2a" strokeDasharray="3 3" />
            <XAxis dataKey="label" stroke="#9a9488" tick={{ fontSize: 11 }} />
            <YAxis
              yAxisId="pain"
              domain={[0, 10]}
              stroke="#f0c14b"
              tick={{ fontSize: 11 }}
              width={32}
            />
            <YAxis
              yAxisId="load"
              orientation="right"
              stroke="#ff6a1a"
              tick={{ fontSize: 11 }}
              width={36}
            />
            <Tooltip
              contentStyle={{ background: "#121212", border: "1px solid #2a2a2a", borderRadius: 12 }}
              labelStyle={{ color: "#f4f0e8" }}
              formatter={(value, name) => {
                if (typeof value !== "number") return ["—", String(name)];
                if (name === "AM pain") return [value, "AM pain"];
                if (name === "Volume") return [Math.round(value), "Volume (kg·s)"];
                return [formatLoad(value, unit), String(name)];
              }}
            />
            <Legend />
            {on.am ? (
              <Line
                yAxisId="pain"
                type="monotone"
                dataKey="am"
                name="AM pain"
                stroke="#f0c14b"
                strokeWidth={2.4}
                dot={{ r: 3 }}
                connectNulls={false}
              />
            ) : null}
            {on.loadL ? (
              <Line
                yAxisId="load"
                type="monotone"
                dataKey="loadL"
                name="Load L"
                stroke="#ff6a1a"
                strokeWidth={2.2}
                dot={{ r: 3 }}
                connectNulls={false}
              />
            ) : null}
            {on.loadR ? (
              <Line
                yAxisId="load"
                type="monotone"
                dataKey="loadR"
                name="Load R"
                stroke="#ffd56a"
                strokeWidth={2.2}
                strokeDasharray="5 4"
                dot={{ r: 3 }}
                connectNulls={false}
              />
            ) : null}
            {on.volume ? (
              <Line
                yAxisId="load"
                type="monotone"
                dataKey="volume"
                name="Volume"
                stroke="#9a9488"
                strokeWidth={1.6}
                dot={false}
                connectNulls={false}
              />
            ) : null}
            <Brush dataKey="label" height={28} stroke="#f0c14b" fill="#1a1a1a" travellerWidth={10} />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
