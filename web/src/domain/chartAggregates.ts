import { type DayCalendar, localCalendar } from "./calendar";
import { workSetsVolumeKgTut } from "./nextLoadSuggester";
import type { DailyCheckIn, ExtensionSet, TrainingSession } from "./types";

export type DayValue = {
  dayKey: string;
  dateMs: number;
  value: number | null;
};

export type PainMetric = "restingAM" | "dailyPM" | "stiffness" | "steps";

export type SessionLoadPoint = {
  dayKey: string;
  dateMs: number;
  sessionId: string;
  loadL: number | null;
  loadR: number | null;
  volumeL: number | null;
  volumeR: number | null;
};

function rangeKeys(dayCount: number, today: Date, calendar: DayCalendar): string[] {
  const start = calendar.startOfDay(today);
  const keys: string[] = [];
  for (let offset = dayCount - 1; offset >= 0; offset -= 1) {
    keys.push(calendar.dayKey(calendar.addDays(start, -offset)));
  }
  return keys;
}

export function painSeries(
  checkIns: DailyCheckIn[],
  metric: PainMetric,
  dayCount: number,
  today: Date,
  calendar: DayCalendar = localCalendar,
): DayValue[] {
  const byDay = new Map<string, DailyCheckIn>();
  for (const row of checkIns) {
    byDay.set(row.dayKey, row);
  }
  return rangeKeys(dayCount, today, calendar).map((key) => {
    const row = byDay.get(key);
    let value: number | null = null;
    if (row) {
      switch (metric) {
        case "restingAM":
          value = row.restingPainAM;
          break;
        case "dailyPM":
          value = row.dailyPainPM;
          break;
        case "stiffness":
          value = row.morningStiffness;
          break;
        case "steps":
          value = row.steps;
          break;
      }
    }
    return {
      dayKey: key,
      dateMs: calendar.startOfDay(parseKey(key, calendar)).getTime(),
      value,
    };
  });
}

function parseKey(key: string, calendar: DayCalendar): Date {
  const [y, m, d] = key.split("-").map(Number);
  if (calendar === localCalendar) return new Date(y, m - 1, d);
  return new Date(Date.UTC(y, m - 1, d));
}

function setTut(set: ExtensionSet, tempoSecondsPerRep: number): number {
  return workSetsVolumeKgTut({
    loadKg: set.loadKg,
    holdSeconds: set.holdSeconds,
    reps: set.reps,
    tempoSecondsPerRep,
  });
}

function maxLoad(sets: ExtensionSet[], side: "L" | "R"): number | null {
  const loads = sets.filter((s) => !s.isWarmup && s.side === side).map((s) => s.loadKg);
  if (loads.length === 0) return null;
  return Math.max(...loads);
}

function sideVolume(sets: ExtensionSet[], side: "L" | "R", tempoSecondsPerRep: number): number | null {
  const work = sets.filter((s) => !s.isWarmup && s.side === side);
  if (work.length === 0) return null;
  const vol = work.reduce((sum, s) => sum + setTut(s, tempoSecondsPerRep), 0);
  return vol > 0 ? vol : null;
}

export function sessionLoadPoints(
  sessions: TrainingSession[],
  tempoSecondsPerRep = 7,
): SessionLoadPoint[] {
  return sessions
    .filter((s) => s.sets.some((set) => !set.isWarmup && set.loadKg > 0))
    .map((s) => ({
      dayKey: s.date,
      dateMs: 0,
      sessionId: s.id,
      loadL: maxLoad(s.sets, "L"),
      loadR: maxLoad(s.sets, "R"),
      volumeL: sideVolume(s.sets, "L", tempoSecondsPerRep),
      volumeR: sideVolume(s.sets, "R", tempoSecondsPerRep),
    }));
}

export function loadSeriesBySide(
  sessions: TrainingSession[],
  side: "L" | "R",
  dayCount: number,
  today: Date,
  calendar: DayCalendar = localCalendar,
): DayValue[] {
  const points = sessionLoadPoints(sessions);
  const maxByDay = new Map<string, number>();
  for (const p of points) {
    const load = side === "L" ? p.loadL : p.loadR;
    if (load === null) continue;
    maxByDay.set(p.dayKey, Math.max(maxByDay.get(p.dayKey) ?? 0, load));
  }
  return rangeKeys(dayCount, today, calendar).map((key) => ({
    dayKey: key,
    dateMs: calendar.startOfDay(parseKey(key, calendar)).getTime(),
    value: maxByDay.get(key) ?? null,
  }));
}

export function volumeSeries(
  sessions: TrainingSession[],
  dayCount: number,
  today: Date,
  calendar: DayCalendar = localCalendar,
): DayValue[] {
  const points = sessionLoadPoints(sessions);
  const volByDay = new Map<string, number>();
  for (const p of points) {
    const v = (p.volumeL ?? 0) + (p.volumeR ?? 0);
    if (v <= 0) continue;
    volByDay.set(p.dayKey, (volByDay.get(p.dayKey) ?? 0) + v);
  }
  return rangeKeys(dayCount, today, calendar).map((key) => ({
    dayKey: key,
    dateMs: calendar.startOfDay(parseKey(key, calendar)).getTime(),
    value: volByDay.get(key) ?? null,
  }));
}

export function volumeSeriesBySide(
  sessions: TrainingSession[],
  side: "L" | "R",
  dayCount: number,
  today: Date,
  calendar: DayCalendar = localCalendar,
): DayValue[] {
  const points = sessionLoadPoints(sessions);
  const volByDay = new Map<string, number>();
  for (const p of points) {
    const v = side === "L" ? p.volumeL : p.volumeR;
    if (v === null || v <= 0) continue;
    volByDay.set(p.dayKey, (volByDay.get(p.dayKey) ?? 0) + v);
  }
  return rangeKeys(dayCount, today, calendar).map((key) => ({
    dayKey: key,
    dateMs: calendar.startOfDay(parseKey(key, calendar)).getTime(),
    value: volByDay.get(key) ?? null,
  }));
}

export function sessionIdByDay(sessions: TrainingSession[]): Map<string, string> {
  const map = new Map<string, string>();
  const sorted = [...sessions].sort((a, b) =>
    a.createdAt > b.createdAt ? -1 : 1,
  );
  for (const s of sorted) {
    if (!map.has(s.date)) map.set(s.date, s.id);
  }
  return map;
}

export function averageOf(series: DayValue[]): number | null {
  const vals = series.map((p) => p.value).filter((v): v is number => v !== null);
  if (vals.length === 0) return null;
  return vals.reduce((a, b) => a + b, 0) / vals.length;
}

export function dayCountForRange(
  range: "7d" | "28d" | "90d" | "all",
  earliestDayKey: string | null,
  today: Date,
  calendar: DayCalendar = localCalendar,
): number {
  if (range === "7d") return 7;
  if (range === "28d") return 28;
  if (range === "90d") return 90;
  if (!earliestDayKey) return 28;
  const todayKey = calendar.dayKey(today);
  const [ty, tm, td] = todayKey.split("-").map(Number);
  const [ey, em, ed] = earliestDayKey.split("-").map(Number);
  const t = Date.UTC(ty, tm - 1, td);
  const e = Date.UTC(ey, em - 1, ed);
  const days = Math.floor((t - e) / 86400000) + 1;
  return Math.max(7, days);
}
