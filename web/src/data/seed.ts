import { localCalendar } from "@/domain/calendar";
import type {
  AppSettings,
  DailyCheckIn,
  ExtensionSet,
  RehabPhase,
  TrainingSession,
} from "@/domain/types";
import { PROTOCOL_REVISION } from "@/domain/types";

function dayKeyOffset(todayKey: string, offset: number): string {
  const [y, m, d] = todayKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + offset);
  return localCalendar.dayKey(date);
}

function isoAt(dayKey: string, hour: number, minute = 0): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  return new Date(y, m - 1, d, hour, minute, 0, 0).toISOString();
}

function id(prefix: string): string {
  return `${prefix}-${crypto.randomUUID()}`;
}

function bothSets(
  loadKg: number,
  count: number,
  kind: "iso" | "hsr",
  pain = 2,
): ExtensionSet[] {
  const sides: Array<"L" | "R"> = ["L", "R"];
  const rows: ExtensionSet[] = [];
  for (const side of sides) {
    for (let i = 0; i < count; i += 1) {
      rows.push({
        id: id(`${side}${i}`),
        side,
        loadKg: side === "R" ? loadKg : loadKg,
        holdSeconds: kind === "iso" ? 45 : null,
        reps: kind === "hsr" ? 8 : null,
        painDuring: pain,
        isWarmup: false,
      });
    }
  }
  return rows;
}

function session(args: {
  offset: number;
  todayKey: string;
  phase: RehabPhase;
  kind: "iso" | "hsr";
  loadKg: number;
  response: TrainingSession["response24h"];
  decision: TrainingSession["decision"];
  painAfter?: number;
}): TrainingSession {
  const date = dayKeyOffset(args.todayKey, args.offset);
  const createdAt = isoAt(date, 18, 10);
  const resolvedAt =
    args.response === "pending" || args.response === "notApplicable"
      ? null
      : isoAt(dayKeyOffset(args.todayKey, args.offset + 1), 8, 5);
  return {
    id: id("ses"),
    date,
    createdAt,
    updatedAt: resolvedAt ?? createdAt,
    phase: args.phase,
    sessionType: args.kind === "iso" ? "isometrics" : "hsrStrength",
    exerciseId: args.kind === "iso" ? "seatedExtensionIso" : "seatedExtensionHsr",
    side: "both",
    kneeAngle: 60,
    tempo: args.kind === "hsr" ? "3-1-3" : null,
    sets: bothSets(args.loadKg, args.kind === "iso" ? 5 : 4, args.kind, args.painAfter ?? 2),
    painAfter: args.painAfter ?? 2,
    notes: "",
    whatIDid:
      args.kind === "iso"
        ? "Single-leg seated knee extension isometric ~60°"
        : "Single-leg seated knee extension HSR 3-1-3",
    response24h: args.response,
    decision: args.decision,
    resolvedAt,
    snoozedUntil: null,
    snoozeUsed: false,
  };
}

export function buildDemoWeek(now = new Date()): {
  settings: AppSettings;
  checkIns: DailyCheckIn[];
  sessions: TrainingSession[];
} {
  const todayKey = localCalendar.dayKey(now);
  const phaseCStart = dayKeyOffset(todayKey, -6);

  const checkIns: DailyCheckIn[] = [];
  for (let offset = -20; offset <= -1; offset += 1) {
    const dayKey = dayKeyOffset(todayKey, offset);
    const early = offset <= -14;
    const am = early ? (offset % 4 === 0 ? 3 : 2) : offset === -10 ? 3 : offset <= -4 ? 2 : 1;
    const steps = 4800 + ((offset + 20) % 5) * 700 + (offset === -8 ? 2200 : 0);
    checkIns.push({
      dayKey,
      date: dayKey,
      restingPainAM: am,
      morningStiffness: Math.max(0, am - 1),
      dailyPainPM: am,
      steps,
      declineSquatL: am + 1,
      declineSquatR: am,
      notes: "",
      phase: offset <= -7 ? "B" : "C",
      createdAt: isoAt(dayKey, 8, 4),
      updatedAt: isoAt(dayKey, 19, 0),
    });
  }

  const sessions: TrainingSession[] = [
    session({ offset: -18, todayKey, phase: "B", kind: "iso", loadKg: 20, response: "better", decision: "stay" }),
    session({ offset: -16, todayKey, phase: "B", kind: "iso", loadKg: 22.5, response: "better", decision: "stay" }),
    session({ offset: -14, todayKey, phase: "B", kind: "iso", loadKg: 25, response: "better", decision: "progress" }),
    session({ offset: -12, todayKey, phase: "B", kind: "iso", loadKg: 27.5, response: "same", decision: "stay" }),
    session({
      offset: -10,
      todayKey,
      phase: "B",
      kind: "iso",
      loadKg: 27.5,
      response: "worse",
      decision: "softCut",
      painAfter: 4,
    }),
    session({ offset: -8, todayKey, phase: "B", kind: "iso", loadKg: 22.5, response: "better", decision: "stay" }),
    session({ offset: -6, todayKey, phase: "C", kind: "hsr", loadKg: 30, response: "better", decision: "stay" }),
    session({ offset: -4, todayKey, phase: "C", kind: "hsr", loadKg: 35, response: "better", decision: "stay" }),
    session({ offset: -2, todayKey, phase: "C", kind: "hsr", loadKg: 40, response: "better", decision: "stay" }),
    session({
      offset: -1,
      todayKey,
      phase: "C",
      kind: "hsr",
      loadKg: 45,
      response: "pending",
      decision: null,
      painAfter: 3,
    }),
  ];

  // Last hard session createdAt ~26h ago so Today still prescribes (yesterday was HSR → off-day)
  // Pending 24h is yesterday's 45 kg HSR.

  const settings: AppSettings = {
    id: "default",
    currentPhase: "C",
    phaseChangedAt: isoAt(phaseCStart, 9),
    phaseAPainThreshold: 2,
    phaseAStableDaysRequired: 3,
    stepNearNormalMin: 6000,
    stepBaselineTypical: 7500,
    hasCompletedOnboarding: true,
    loadUnit: "lb",
    isoProtocol: "holds45",
    protocolRevision: PROTOCOL_REVISION,
    demoSeeded: true,
  };

  return { settings, checkIns, sessions };
}
