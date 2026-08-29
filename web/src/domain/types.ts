export const REHAB_PHASES = ["A", "B", "C", "D", "E"] as const;
export type RehabPhase = (typeof REHAB_PHASES)[number];

export const SESSION_TYPES = [
  "isometrics",
  "hsrStrength",
  "energyStorage",
  "tennisSport",
  "other",
] as const;
export type SessionType = (typeof SESSION_TYPES)[number];

export const RESPONSES_24H = [
  "pending",
  "better",
  "same",
  "worse",
  "notApplicable",
] as const;
export type Response24h = (typeof RESPONSES_24H)[number];

export const SESSION_DECISIONS = [
  "stay",
  "softCut",
  "progress",
  "hardDrop",
  "rest",
] as const;
export type SessionDecision = (typeof SESSION_DECISIONS)[number];

export const LOAD_UNITS = ["kg", "lb"] as const;
export type LoadUnit = (typeof LOAD_UNITS)[number];

export const ISO_PROTOCOLS = ["holds45", "rioPulses"] as const;
export type IsoProtocol = (typeof ISO_PROTOCOLS)[number];

export type Side = "L" | "R";
export type SessionSide = "L" | "R" | "both";

export const EXERCISE_IDS = [
  "seatedExtensionIso",
  "seatedExtensionHsr",
  "wallSit",
  "spanishSquat",
  "landings",
  "hitting",
  "match",
  "bike",
  "walk",
  "custom",
] as const;
export type ExerciseId = (typeof EXERCISE_IDS)[number];

export type DailyCheckInSnapshot = {
  date: string;
  restingPainAM: number | null;
  steps: number | null;
};

export type TrainingSessionSnapshot = {
  id: string;
  date: string;
  createdAt: string;
  sessionType: SessionType;
  response24h: Response24h;
  decision: SessionDecision | null;
  resolvedAt: string | null;
  snoozedUntil: string | null;
  phase: RehabPhase;
};

export type PhaseSettingsSnapshot = {
  currentPhase: RehabPhase;
  phaseChangedAt: string;
  phaseAPainThreshold: number;
  phaseAStableDaysRequired: number;
  stepNearNormalMin: number;
  amReminderHour: number;
  amReminderMinute: number;
};

export const DEFAULT_PHASE_SETTINGS: PhaseSettingsSnapshot = {
  currentPhase: "B",
  phaseChangedAt: "1970-01-01T00:00:00.000Z",
  phaseAPainThreshold: 2,
  phaseAStableDaysRequired: 3,
  stepNearNormalMin: 6000,
  amReminderHour: 8,
  amReminderMinute: 0,
};

export type ExtensionSet = {
  id: string;
  side: Side;
  loadKg: number;
  holdSeconds: number | null;
  reps: number | null;
  painDuring: number;
  isWarmup: boolean;
};

export type DailyCheckIn = {
  dayKey: string;
  date: string;
  restingPainAM: number | null;
  morningStiffness: number | null;
  dailyPainPM: number | null;
  steps: number | null;
  declineSquatL: number | null;
  declineSquatR: number | null;
  notes: string;
  phase: RehabPhase;
  createdAt: string;
  updatedAt: string;
};

export type TrainingSession = {
  id: string;
  date: string;
  createdAt: string;
  updatedAt: string;
  phase: RehabPhase;
  sessionType: SessionType;
  exerciseId: ExerciseId;
  side: SessionSide;
  kneeAngle: number;
  tempo: string | null;
  sets: ExtensionSet[];
  painAfter: number;
  notes: string;
  whatIDid: string;
  response24h: Response24h;
  decision: SessionDecision | null;
  resolvedAt: string | null;
  snoozedUntil: string | null;
  snoozeUsed: boolean;
};

export type AppSettings = {
  id: "default";
  currentPhase: RehabPhase;
  phaseChangedAt: string;
  phaseAPainThreshold: number;
  phaseAStableDaysRequired: number;
  stepNearNormalMin: number;
  stepBaselineTypical: number;
  hasCompletedOnboarding: boolean;
  loadUnit: LoadUnit;
  isoProtocol: IsoProtocol;
  protocolRevision: string;
  demoSeeded: boolean;
};

export const PROTOCOL_REVISION = "web-2.0 · 2026-08-29";

export const DISCLAIMER =
  "R3hab is not a medical device. It supports self-managed patellar tendinopathy rehab logging and does not diagnose, treat, or replace professional care.";

export function sessionToSnapshot(session: TrainingSession): TrainingSessionSnapshot {
  return {
    id: session.id,
    date: session.date,
    createdAt: session.createdAt,
    sessionType: session.sessionType,
    response24h: session.response24h,
    decision: session.decision,
    resolvedAt: session.resolvedAt,
    snoozedUntil: session.snoozedUntil,
    phase: session.phase,
  };
}

export function checkInToSnapshot(row: DailyCheckIn): DailyCheckInSnapshot {
  return {
    date: row.dayKey,
    restingPainAM: row.restingPainAM,
    steps: row.steps,
  };
}

export function settingsToPhaseSnapshot(settings: AppSettings): PhaseSettingsSnapshot {
  return {
    currentPhase: settings.currentPhase,
    phaseChangedAt: settings.phaseChangedAt,
    phaseAPainThreshold: settings.phaseAPainThreshold,
    phaseAStableDaysRequired: settings.phaseAStableDaysRequired,
    stepNearNormalMin: settings.stepNearNormalMin,
    amReminderHour: 8,
    amReminderMinute: 0,
  };
}

export function defaultSettings(): AppSettings {
  return {
    id: "default",
    currentPhase: "B",
    phaseChangedAt: new Date().toISOString(),
    phaseAPainThreshold: 2,
    phaseAStableDaysRequired: 3,
    stepNearNormalMin: 6000,
    stepBaselineTypical: 7500,
    hasCompletedOnboarding: false,
    loadUnit: "kg",
    isoProtocol: "holds45",
    protocolRevision: PROTOCOL_REVISION,
    demoSeeded: false,
  };
}

export const PHASE_TITLES: Record<RehabPhase, string> = {
  A: "A · Flare / protect",
  B: "B · Isometrics",
  C: "C · Heavy slow resistance",
  D: "D · Energy storage",
  E: "E · Return to tennis",
};

export const PHASE_SHORT: Record<RehabPhase, string> = {
  A: "Flare",
  B: "Isometrics",
  C: "HSR",
  D: "Energy",
  E: "Tennis",
};

export const SESSION_TYPE_TITLES: Record<SessionType, string> = {
  isometrics: "Isometrics",
  hsrStrength: "HSR",
  energyStorage: "Energy",
  tennisSport: "Tennis",
  other: "Other",
};

export const DECISION_TITLES: Record<SessionDecision, string> = {
  stay: "Stay",
  softCut: "Soft cut",
  progress: "Progress",
  hardDrop: "Hard drop",
  rest: "Rest",
};

export const RESPONSE_TITLES: Record<Response24h, string> = {
  pending: "Pending",
  better: "Better",
  same: "Same",
  worse: "Worse",
  notApplicable: "N/A",
};

export const EXERCISE_TITLES: Record<ExerciseId, string> = {
  seatedExtensionIso: "Seated knee extension isometric",
  seatedExtensionHsr: "Seated knee extension HSR",
  wallSit: "Wall sit",
  spanishSquat: "Spanish squat",
  landings: "Low-volume landings",
  hitting: "Tennis: hitting",
  match: "Tennis: match play",
  bike: "Easy bike",
  walk: "Walk",
  custom: "Custom",
};

export function earlierPhases(current: RehabPhase): RehabPhase[] {
  const order: RehabPhase[] = ["A", "B", "C", "D", "E"];
  const idx = order.indexOf(current);
  return order.slice(0, Math.max(0, idx));
}

export function previousPhase(current: RehabPhase): RehabPhase | null {
  if (current === "E") return "C";
  const earlier = earlierPhases(current);
  return earlier.length > 0 ? earlier[earlier.length - 1] : null;
}

export function isClinicalResponse(response: Response24h): boolean {
  return response === "better" || response === "same" || response === "worse";
}
