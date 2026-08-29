import type { AppSettings, DailyCheckIn, TrainingSession } from "@/domain/types";
import { defaultSettings } from "@/domain/types";

export const SCHEMA_VERSION = 2;

export type BackupV2 = {
  schemaVersion: number;
  exportedAt: string;
  settings: AppSettings;
  dailyCheckIns: DailyCheckIn[];
  trainingSessions: TrainingSession[];
};

export class BackupError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BackupError";
  }
}

export function serializeBackup(data: {
  settings: AppSettings;
  checkIns: DailyCheckIn[];
  sessions: TrainingSession[];
}): string {
  const backup: BackupV2 = {
    schemaVersion: SCHEMA_VERSION,
    exportedAt: new Date().toISOString(),
    settings: data.settings,
    dailyCheckIns: data.checkIns,
    trainingSessions: data.sessions,
  };
  return JSON.stringify(backup, null, 2);
}

export function parseBackup(text: string): BackupV2 {
  let raw: unknown;
  try {
    raw = JSON.parse(text) as unknown;
  } catch {
    throw new BackupError("Could not read this backup file.");
  }
  if (!raw || typeof raw !== "object") {
    throw new BackupError("Backup file is empty.");
  }
  const obj = raw as Record<string, unknown>;
  const version = obj.schemaVersion;
  if (typeof version !== "number") {
    throw new BackupError("Missing schemaVersion.");
  }
  if (version !== SCHEMA_VERSION) {
    throw new BackupError(`Unsupported backup version ${version}. This app reads schemaVersion ${SCHEMA_VERSION}.`);
  }
  return {
    schemaVersion: version,
    exportedAt: typeof obj.exportedAt === "string" ? obj.exportedAt : new Date().toISOString(),
    settings: { ...defaultSettings(), ...(obj.settings as AppSettings) },
    dailyCheckIns: Array.isArray(obj.dailyCheckIns) ? (obj.dailyCheckIns as DailyCheckIn[]) : [],
    trainingSessions: Array.isArray(obj.trainingSessions)
      ? (obj.trainingSessions as TrainingSession[])
      : [],
  };
}

export function mergeBackup(
  local: { settings: AppSettings; checkIns: DailyCheckIn[]; sessions: TrainingSession[] },
  incoming: BackupV2,
): { settings: AppSettings; checkIns: DailyCheckIn[]; sessions: TrainingSession[] } {
  const checkMap = new Map(local.checkIns.map((c) => [c.dayKey, c]));
  for (const row of incoming.dailyCheckIns) {
    const existing = checkMap.get(row.dayKey);
    checkMap.set(row.dayKey, existing ? { ...existing, ...row, dayKey: existing.dayKey } : row);
  }
  const sessionMap = new Map(local.sessions.map((s) => [s.id, s]));
  for (const row of incoming.trainingSessions) {
    sessionMap.set(row.id, row);
  }
  return {
    settings: { ...local.settings, ...incoming.settings, id: "default" },
    checkIns: [...checkMap.values()],
    sessions: [...sessionMap.values()],
  };
}
