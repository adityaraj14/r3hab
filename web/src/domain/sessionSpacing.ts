import type { SessionType, TrainingSessionSnapshot } from "./types";

/** Port of R3hab/Domain/SessionSpacing.swift */
export function isHardSession(type: SessionType): boolean {
  return (
    type === "isometrics" ||
    type === "hsrStrength" ||
    type === "energyStorage" ||
    type === "tennisSport"
  );
}

export function hoursSinceLastHard(
  sessions: TrainingSessionSnapshot[],
  now: Date,
  excludingId: string | null = null,
): number | null {
  const hard = sessions
    .filter((s) => isHardSession(s.sessionType))
    .filter((s) => excludingId === null || s.id !== excludingId)
    .sort((a, b) => {
      if (a.date !== b.date) return a.date > b.date ? -1 : 1;
      return a.createdAt > b.createdAt ? -1 : 1;
    });
  const last = hard[0];
  if (!last) return null;
  return (now.getTime() - Date.parse(last.createdAt)) / 3600000;
}

export function shouldWarnUnder48h(
  sessions: TrainingSessionSnapshot[],
  newType: SessionType,
  now: Date,
  excludingId: string | null = null,
): boolean {
  if (!isHardSession(newType)) return false;
  const hours = hoursSinceLastHard(sessions, now, excludingId);
  if (hours === null) return false;
  return hours < 48;
}

export function lastHardSessionDate(
  sessions: TrainingSessionSnapshot[],
  excludingId: string | null = null,
): string | null {
  const hard = sessions
    .filter((s) => isHardSession(s.sessionType))
    .filter((s) => excludingId === null || s.id !== excludingId)
    .sort((a, b) => {
      if (a.date !== b.date) return a.date > b.date ? -1 : 1;
      return a.createdAt > b.createdAt ? -1 : 1;
    });
  return hard[0]?.date ?? null;
}

export function lastSessionOfTypeDate(
  sessions: TrainingSessionSnapshot[],
  type: SessionType,
): string | null {
  const match = sessions
    .filter((s) => s.sessionType === type)
    .sort((a, b) => (a.date > b.date ? -1 : 1));
  return match[0]?.date ?? null;
}
