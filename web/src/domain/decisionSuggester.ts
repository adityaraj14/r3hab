import type { Response24h, SessionDecision, TrainingSessionSnapshot } from "./types";

/**
 * Suggest decision from 24h response using session-date chronology only (KD-18).
 * Port of R3hab/Domain/DecisionSuggester.swift
 *
 * - recentResolvedNonRest: prior non-Rest Better/Same/Worse, sorted date desc, createdAt desc
 */
export function suggestDecision(
  response: Response24h,
  recentResolvedNonRest: Response24h[],
  cleanN = 3,
): SessionDecision | null {
  switch (response) {
    case "pending":
    case "notApplicable":
      return null;
    case "same":
      return "stay";
    case "better": {
      const streak = recentResolvedNonRest.slice(0, cleanN);
      const allClean =
        streak.length === cleanN && streak.every((item) => item === "better" || item === "same");
      return allClean ? "progress" : "stay";
    }
    case "worse":
      if (recentResolvedNonRest[0] === "worse") return "hardDrop";
      return "softCut";
    default:
      return null;
  }
}

/** Resolved non-Rest sessions excluding `id`, newest session-date first. Never uses resolvedAt. */
export function clinicalResolvedSortedDescending(
  all: TrainingSessionSnapshot[],
  excludingId: string | null,
): TrainingSessionSnapshot[] {
  return all
    .filter((session) => {
      if (excludingId && session.id === excludingId) return false;
      if (session.decision === "rest") return false;
      return (
        session.response24h === "better" ||
        session.response24h === "same" ||
        session.response24h === "worse"
      );
    })
    .sort((a, b) => {
      if (a.date !== b.date) return a.date > b.date ? -1 : 1;
      return a.createdAt > b.createdAt ? -1 : 1;
    });
}

export function priorsForSuggestion(
  current: TrainingSessionSnapshot,
  all: TrainingSessionSnapshot[],
): Response24h[] {
  return clinicalResolvedSortedDescending(all, current.id).map((s) => s.response24h);
}

export function guidanceForDecision(decision: SessionDecision): string | null {
  switch (decision) {
    case "softCut":
      return "Soft cut: stay in this phase, do less next time (−20–30% load, shorter holds, or fewer sets).";
    case "hardDrop":
      return "Hard drop: step back a phase when ready (e.g. C→B or B→A). Confirm phase change only if you intend it.";
    default:
      return null;
  }
}

export function countCleanSessionsSince(
  sessions: TrainingSessionSnapshot[],
  phaseChangedAtIso: string,
  phase: TrainingSessionSnapshot["phase"],
): number {
  const changedDay = phaseChangedAtIso.slice(0, 10);
  return sessions.filter((session) => {
    if (session.phase !== phase) return false;
    if (session.date < changedDay) return false;
    return session.response24h === "better" || session.response24h === "same";
  }).length;
}
