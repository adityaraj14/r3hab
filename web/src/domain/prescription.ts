import { localCalendar, type DayCalendar } from "./calendar";
import { suggestNextLoad } from "./nextLoadSuggester";
import { lastHardSessionDate, shouldWarnUnder48h } from "./sessionSpacing";
import { countCleanSessionsSince } from "./decisionSuggester";
import type {
  AppSettings,
  DailyCheckIn,
  ExerciseId,
  ExtensionSet,
  IsoProtocol,
  RehabPhase,
  SessionType,
  Side,
  TrainingSession,
} from "./types";
import { sessionToSnapshot } from "./types";

export type TodayPrescription = {
  kind:
    | "walk"
    | "rest"
    | "easyBike"
    | "isoExtension"
    | "hsrExtension"
    | "isoOffDay"
    | "energyStorage"
    | "tennisHitting"
    | "tennisMatch";
  title: string;
  subtitle: string;
  exerciseId: ExerciseId;
  sessionType: SessionType;
  side: "both";
  kneeAngle: number;
  loadKgL: number | null;
  loadKgR: number | null;
  sets: number;
  holdSeconds: number | null;
  reps: number | null;
  tempo: string | null;
  restSeconds: number | null;
  effort: string | null;
  isoProtocol: IsoProtocol | null;
  warnings: string[];
  rationale: string;
  cta: string;
  isHard: boolean;
};

const DEFAULT_ISO_LOAD = 20;
const DEFAULT_HSR_LOAD = 25;
const DEFAULT_HSR_REPS = 8;
const DEFAULT_HSR_SETS = 4;
const DEFAULT_ISO_SETS = 5;
const DEFAULT_HOLD = 45;

function lastWorkLoad(sets: ExtensionSet[], side: Side): number | null {
  const work = sets.filter((s) => !s.isWarmup && s.side === side && s.loadKg > 0);
  if (work.length === 0) return null;
  return work[work.length - 1].loadKg;
}

function lastWorkReps(sets: ExtensionSet[], side: Side): number | null {
  const work = sets.filter((s) => !s.isWarmup && s.side === side);
  const last = work[work.length - 1];
  return last?.reps ?? null;
}

function lastWorkHold(sets: ExtensionSet[], side: Side): number | null {
  const work = sets.filter((s) => !s.isWarmup && s.side === side);
  const last = work[work.length - 1];
  return last?.holdSeconds ?? null;
}

export function lastLoadsBySide(
  sessions: TrainingSession[],
  exerciseMatch?: (s: TrainingSession) => boolean,
): { L: number | null; R: number | null; repsL: number | null; repsR: number | null; holdL: number | null; holdR: number | null; lastDecision: TrainingSession["decision"]; lastSession: TrainingSession | null } {
  const sorted = [...sessions].sort((a, b) => {
    if (a.date !== b.date) return a.date > b.date ? -1 : 1;
    return a.createdAt > b.createdAt ? -1 : 1;
  });
  let L: number | null = null;
  let R: number | null = null;
  let repsL: number | null = null;
  let repsR: number | null = null;
  let holdL: number | null = null;
  let holdR: number | null = null;
  let lastSession: TrainingSession | null = null;
  for (const s of sorted) {
    if (exerciseMatch && !exerciseMatch(s)) continue;
    if (s.sets.length === 0) continue;
    if (!lastSession) lastSession = s;
    if (L === null) {
      const v = lastWorkLoad(s.sets, "L");
      if (v !== null) {
        L = v;
        repsL = lastWorkReps(s.sets, "L");
        holdL = lastWorkHold(s.sets, "L");
      }
    }
    if (R === null) {
      const v = lastWorkLoad(s.sets, "R");
      if (v !== null) {
        R = v;
        repsR = lastWorkReps(s.sets, "R");
        holdR = lastWorkHold(s.sets, "R");
      }
    }
    if (L !== null && R !== null) break;
  }
  const lastResolved = sorted.find(
    (s) => s.decision && s.decision !== "rest" && s.response24h !== "pending",
  );
  return {
    L,
    R,
    repsL,
    repsR,
    holdL,
    holdR,
    lastDecision: lastResolved?.decision ?? null,
    lastSession,
  };
}

function hsrDaysThisWeek(
  sessions: TrainingSession[],
  todayKey: string,
  calendar: DayCalendar,
): string[] {
  const today = calendar.startOfDay(parseLocal(todayKey, calendar));
  const dow = calendar === localCalendar ? today.getDay() : today.getUTCDay();
  const mondayOffset = dow === 0 ? -6 : 1 - dow;
  const monday = calendar.addDays(today, mondayOffset);
  const mondayKey = calendar.dayKey(monday);
  return sessions
    .filter((s) => s.sessionType === "hsrStrength" && s.date >= mondayKey && s.date <= todayKey)
    .map((s) => s.date);
}

function parseLocal(dayKey: string, calendar: DayCalendar): Date {
  const [y, m, d] = dayKey.split("-").map(Number);
  if (calendar === localCalendar) return new Date(y, m - 1, d);
  return new Date(Date.UTC(y, m - 1, d));
}

function yesterdayKey(todayKey: string, calendar: DayCalendar): string {
  return calendar.dayKey(calendar.addDays(parseLocal(todayKey, calendar), -1));
}

export function prescribeToday(args: {
  settings: AppSettings;
  checkIn: DailyCheckIn | null;
  sessions: TrainingSession[];
  now?: Date;
  calendar?: DayCalendar;
}): TodayPrescription {
  const calendar = args.calendar ?? localCalendar;
  const now = args.now ?? new Date();
  const todayKey = calendar.dayKey(now);
  const snaps = args.sessions.map(sessionToSnapshot);
  const phase = args.settings.currentPhase;
  const warnings: string[] = [];

  const isoLoads = lastLoadsBySide(
    args.sessions,
    (s) => s.exerciseId === "seatedExtensionIso",
  );
  const hsrLoads = lastLoadsBySide(
    args.sessions,
    (s) => s.exerciseId === "seatedExtensionHsr",
  );

  const applyDecision = (
    load: number | null,
    hold: number | null,
    reps: number | null,
    decision: TrainingSession["decision"],
  ) => {
    if (load === null) {
      return { loadKg: null as number | null, holdSeconds: hold, reps };
    }
    const next = suggestNextLoad({
      lastLoadKg: load,
      lastReps: reps,
      lastHoldSeconds: hold,
      decision,
      unit: args.settings.loadUnit,
    });
    return { loadKg: next.loadKg, holdSeconds: next.holdSeconds, reps: next.reps };
  };

  const nextIsoL = applyDecision(isoLoads.L, isoLoads.holdL, isoLoads.repsL, isoLoads.lastDecision);
  const nextIsoR = applyDecision(isoLoads.R, isoLoads.holdR, isoLoads.repsR, isoLoads.lastDecision);
  const nextHsrL = applyDecision(hsrLoads.L, null, hsrLoads.repsL, hsrLoads.lastDecision);
  const nextHsrR = applyDecision(hsrLoads.R, null, hsrLoads.repsR, hsrLoads.lastDecision);

  const warn48 = (type: SessionType) => {
    if (shouldWarnUnder48h(snaps, type, now)) {
      warnings.push("Last hard session was under 48h ago. Warn, not a block — skip or go easy if the tendon feels cooked.");
    }
  };

  if (phase === "A") {
    const am = args.checkIn?.restingPainAM ?? null;
    const high = am !== null && am > args.settings.phaseAPainThreshold;
    return {
      kind: high ? "rest" : "walk",
      title: high ? "Protect day" : "Walk day",
      subtitle: high
        ? "AM pain is above threshold. Relative rest. No heavy extension, no impact, no tennis."
        : "Walk toward 6–8k if AM pain stays ≤ threshold. Optional easy bike. No heavy extension.",
      exerciseId: high ? "walk" : "walk",
      sessionType: "other",
      side: "both",
      kneeAngle: 60,
      loadKgL: null,
      loadKgR: null,
      sets: 0,
      holdSeconds: null,
      reps: null,
      tempo: null,
      restSeconds: null,
      effort: null,
      isoProtocol: null,
      warnings,
      rationale: "Phase A is flare / protect. Rest is not the treatment — keep easy walking if pain allows, then rebuild.",
      cta: high ? "Log a rest day" : "Log walk / easy bike",
      isHard: false,
    };
  }

  if (phase === "B") {
    warn48("isometrics");
    const proto = args.settings.isoProtocol;
    const hold = proto === "holds45" ? (nextIsoL.holdSeconds ?? nextIsoR.holdSeconds ?? DEFAULT_HOLD) : 3;
    const sets = DEFAULT_ISO_SETS;
    const clean = countCleanSessionsSince(snaps, args.settings.phaseChangedAt, "B");
    const rationale =
      clean >= 4
        ? `${clean} clean 24h sessions since entering B. If resting pain stays low, consider Phase C (you switch it).`
        : "Primary: single-leg seated knee extension isometric at ~60°. Optional alts (wall sit, Spanish squat) are secondary.";
    return {
      kind: "isoExtension",
      title: proto === "rioPulses" ? "Iso pulses · seated extension" : "Isometrics · seated extension",
      subtitle:
        proto === "rioPulses"
          ? "5 sets × 4 × 3s max-effort pulses, each side, ~60°."
          : `5 × ${hold}s holds @ ~70% effort, 2 min rest, each side, ~60°.`,
      exerciseId: "seatedExtensionIso",
      sessionType: "isometrics",
      side: "both",
      kneeAngle: 60,
      loadKgL: nextIsoL.loadKg ?? DEFAULT_ISO_LOAD,
      loadKgR: nextIsoR.loadKg ?? DEFAULT_ISO_LOAD,
      sets,
      holdSeconds: hold,
      reps: proto === "rioPulses" ? 4 : null,
      tempo: null,
      restSeconds: 120,
      effort: proto === "rioPulses" ? "max" : "~70%",
      isoProtocol: proto,
      warnings,
      rationale,
      cta: "Start extension session",
      isHard: true,
    };
  }

  if (phase === "C") {
    const lastHsr = lastHardSessionDate(
      snaps.filter((s) => s.sessionType === "hsrStrength"),
    );
    const yKey = yesterdayKey(todayKey, calendar);
    const consecutive = lastHsr === yKey;
    const week = hsrDaysThisWeek(args.sessions, todayKey, calendar);
    const hsrCount = week.filter((d) => d !== todayKey).length;

    if (consecutive || hsrCount >= 3) {
      warn48("isometrics");
      return {
        kind: "isoOffDay",
        title: consecutive ? "Off-day isometric" : "HSR quota hit · iso or walk",
        subtitle: consecutive
          ? "HSR never on consecutive days. Optional seated-extension isometric for analgesia, or walk."
          : "Already 3 HSR days this week. Keep an easy iso or walk today.",
        exerciseId: "seatedExtensionIso",
        sessionType: "isometrics",
        side: "both",
        kneeAngle: 60,
        loadKgL: nextIsoL.loadKg ?? DEFAULT_ISO_LOAD,
        loadKgR: nextIsoR.loadKg ?? DEFAULT_ISO_LOAD,
        sets: 3,
        holdSeconds: nextIsoL.holdSeconds ?? DEFAULT_HOLD,
        reps: null,
        tempo: null,
        restSeconds: 120,
        effort: "~70%",
        isoProtocol: args.settings.isoProtocol,
        warnings,
        rationale: "Phase C is capacity. 3–4×/week HSR, never consecutive. Isometrics on off days if they help.",
        cta: "Start off-day iso",
        isHard: true,
      };
    }

    warn48("hsrStrength");
    return {
      kind: "hsrExtension",
      title: "HSR · seated extension",
      subtitle: "Single-leg seated knee extension. 3–4 × 6–15, tempo 3s down / 1s pause / 3s up. Pain ≤5/10 during is OK if tomorrow morning is not worse.",
      exerciseId: "seatedExtensionHsr",
      sessionType: "hsrStrength",
      side: "both",
      kneeAngle: 60,
      loadKgL: nextHsrL.loadKg ?? DEFAULT_HSR_LOAD,
      loadKgR: nextHsrR.loadKg ?? DEFAULT_HSR_LOAD,
      sets: DEFAULT_HSR_SETS,
      holdSeconds: null,
      reps: nextHsrL.reps ?? nextHsrR.reps ?? DEFAULT_HSR_REPS,
      tempo: "3-1-3",
      restSeconds: 120,
      effort: "last 2 reps hard",
      isoProtocol: null,
      warnings,
      rationale: "Primary HSR exercise is seated knee extension — isolates the quads and tendon. Progress load when the last 2 reps get hard.",
      cta: "Start HSR session",
      isHard: true,
    };
  }

  if (phase === "D") {
    const lastHsr = lastHardSessionDate(
      snaps.filter((s) => s.sessionType === "hsrStrength"),
    );
    const yKey = yesterdayKey(todayKey, calendar);
    const week = hsrDaysThisWeek(args.sessions, todayKey, calendar);
    const needHsr = lastHsr !== yKey && week.filter((d) => d !== todayKey).length < 2;

    if (needHsr) {
      warn48("hsrStrength");
      return {
        kind: "hsrExtension",
        title: "Keep HSR · seated extension",
        subtitle: "Energy-storage phase still keeps 1–2 HSR extension days. Today is a strength day.",
        exerciseId: "seatedExtensionHsr",
        sessionType: "hsrStrength",
        side: "both",
        kneeAngle: 60,
        loadKgL: nextHsrL.loadKg ?? DEFAULT_HSR_LOAD,
        loadKgR: nextHsrR.loadKg ?? DEFAULT_HSR_LOAD,
        sets: DEFAULT_HSR_SETS,
        holdSeconds: null,
        reps: nextHsrL.reps ?? DEFAULT_HSR_REPS,
        tempo: "3-1-3",
        restSeconds: 120,
        effort: "last 2 reps hard",
        isoProtocol: null,
        warnings,
        rationale: "Do not drop HSR just because plyos started. Soft-cut plyo volume first if 24h is worse.",
        cta: "Start HSR session",
        isHard: true,
      };
    }

    warn48("energyStorage");
    const lastPlyo = [...args.sessions]
      .filter((s) => s.sessionType === "energyStorage")
      .sort((a, b) => (a.date > b.date ? -1 : 1))[0];
    const cutPlyo = lastPlyo?.response24h === "worse";
    return {
      kind: "energyStorage",
      title: cutPlyo ? "Plyos · soft-cut volume" : "Energy storage · low-volume landings",
      subtitle: cutPlyo
        ? "Last plyo 24h was Worse. Cut landing volume 50% today. Keep HSR later this week."
        : "Low-volume landings / small jumps. Quality over volume. Keep 1–2 HSR extension days this week.",
      exerciseId: "landings",
      sessionType: "energyStorage",
      side: "both",
      kneeAngle: 60,
      loadKgL: null,
      loadKgR: null,
      sets: cutPlyo ? 3 : 6,
      holdSeconds: null,
      reps: 4,
      tempo: null,
      restSeconds: 90,
      effort: "quiet landings",
      isoProtocol: null,
      warnings,
      rationale: "Soft-cut plyo volume first if 24h worse. Do not pull HSR first.",
      cta: "Log landings",
      isHard: true,
    };
  }

  // Phase E
  const lastHsr = lastHardSessionDate(
    snaps.filter((s) => s.sessionType === "hsrStrength"),
  );
  const yKey = yesterdayKey(todayKey, calendar);
  const week = hsrDaysThisWeek(args.sessions, todayKey, calendar);
  const needHsr = lastHsr !== yKey && week.filter((d) => d !== todayKey).length < 2;

  if (needHsr) {
    warn48("hsrStrength");
    return {
      kind: "hsrExtension",
      title: "Maintenance HSR · seated extension",
      subtitle: "Return to tennis keeps 1–2 HSR extension days. Do not drop the gym just because you are hitting.",
      exerciseId: "seatedExtensionHsr",
      sessionType: "hsrStrength",
      side: "both",
      kneeAngle: 60,
      loadKgL: nextHsrL.loadKg ?? DEFAULT_HSR_LOAD,
      loadKgR: nextHsrR.loadKg ?? DEFAULT_HSR_LOAD,
      sets: 3,
      holdSeconds: null,
      reps: nextHsrL.reps ?? DEFAULT_HSR_REPS,
      tempo: "3-1-3",
      restSeconds: 120,
      effort: "last 2 reps hard",
      isoProtocol: null,
      warnings,
      rationale: "Never skip here from A/B. Graded hitting sits on top of maintained HSR.",
      cta: "Start HSR session",
      isHard: true,
    };
  }

  warn48("tennisSport");
  return {
    kind: "tennisHitting",
    title: "Tennis · graded hitting",
    subtitle: "Short hitting session. Keep volume honest. Match play only after hitting 24h stays clean.",
    exerciseId: "hitting",
    sessionType: "tennisSport",
    side: "both",
    kneeAngle: 60,
    loadKgL: null,
    loadKgR: null,
    sets: 0,
    holdSeconds: null,
    reps: null,
    tempo: null,
    restSeconds: null,
    effort: null,
    isoProtocol: null,
    warnings,
    rationale: "Return is graded hitting → match play. Next morning is the source of truth.",
    cta: "Log tennis",
    isHard: true,
  };
}

export function defaultSetsFromPrescription(p: TodayPrescription): ExtensionSet[] {
  if (p.loadKgL === null && p.loadKgR === null) return [];
  const rows: ExtensionSet[] = [];
  const sides: Side[] = ["L", "R"];
  for (const side of sides) {
    const load = side === "L" ? p.loadKgL : p.loadKgR;
    if (load === null) continue;
    for (let i = 0; i < p.sets; i += 1) {
      rows.push({
        id: `${side}-${i}`,
        side,
        loadKg: load,
        holdSeconds: p.holdSeconds,
        reps: p.reps,
        painDuring: null,
        isWarmup: false,
      });
    }
  }
  return rows;
}
