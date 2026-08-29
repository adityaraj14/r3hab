"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { db } from "./db";
import { parseBackup, serializeBackup, mergeBackup, type BackupV2 } from "./exportImport";
import { buildDemoWeek } from "./seed";
import {
  defaultSettings,
  type AppSettings,
  type DailyCheckIn,
  type RehabPhase,
  type SessionDecision,
  type Response24h,
  type TrainingSession,
} from "@/domain/types";

type StoreValue = {
  ready: boolean;
  settings: AppSettings;
  checkIns: DailyCheckIn[];
  sessions: TrainingSession[];
  refresh: () => Promise<void>;
  upsertCheckIn: (row: DailyCheckIn) => Promise<void>;
  saveSession: (row: TrainingSession) => Promise<void>;
  deleteSession: (id: string) => Promise<void>;
  deleteCheckIn: (dayKey: string) => Promise<void>;
  resolveSession: (args: {
    id: string;
    response: Response24h;
    decision: SessionDecision;
    nextPhase?: RehabPhase | null;
  }) => Promise<void>;
  snoozeSession: (id: string, untilIso: string) => Promise<void>;
  updateSettings: (patch: Partial<AppSettings>) => Promise<void>;
  exportJson: () => Promise<string>;
  importJson: (text: string, mode: "replace" | "merge") => Promise<void>;
  clearLogs: () => Promise<void>;
  loadDemo: () => Promise<void>;
};

const StoreContext = createContext<StoreValue | null>(null);

async function readAll(): Promise<{
  settings: AppSettings;
  checkIns: DailyCheckIn[];
  sessions: TrainingSession[];
}> {
  let settings = await db.settings.get("default");
  if (!settings) {
    settings = defaultSettings();
    await db.settings.put(settings);
  }
  const checkIns = await db.checkIns.toArray();
  const sessions = await db.sessions.toArray();
  return { settings, checkIns, sessions };
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [settings, setSettings] = useState<AppSettings>(defaultSettings());
  const [checkIns, setCheckIns] = useState<DailyCheckIn[]>([]);
  const [sessions, setSessions] = useState<TrainingSession[]>([]);

  const refresh = useCallback(async () => {
    const data = await readAll();
    setSettings(data.settings);
    setCheckIns(data.checkIns);
    setSessions(data.sessions);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const data = await readAll();
      const isDev = process.env.NODE_ENV === "development";
      if (isDev && !data.settings.demoSeeded && data.checkIns.length === 0 && data.sessions.length === 0) {
        const demo = buildDemoWeek();
        await db.transaction("rw", db.settings, db.checkIns, db.sessions, async () => {
          await db.settings.put({
            ...demo.settings,
            hasCompletedOnboarding: data.settings.hasCompletedOnboarding,
          });
          await db.checkIns.bulkPut(demo.checkIns);
          await db.sessions.bulkPut(demo.sessions);
        });
      }
      if (cancelled) return;
      await refresh();
      setReady(true);
    })();
    return () => {
      cancelled = true;
    };
  }, [refresh]);

  const upsertCheckIn = useCallback(async (row: DailyCheckIn) => {
    await db.checkIns.put(row);
    await refresh();
  }, [refresh]);

  const saveSession = useCallback(async (row: TrainingSession) => {
    await db.sessions.put(row);
    await refresh();
  }, [refresh]);

  const deleteSession = useCallback(async (id: string) => {
    await db.sessions.delete(id);
    await refresh();
  }, [refresh]);

  const deleteCheckIn = useCallback(async (dayKey: string) => {
    await db.checkIns.delete(dayKey);
    await refresh();
  }, [refresh]);

  const resolveSession = useCallback(
    async (args: {
      id: string;
      response: Response24h;
      decision: SessionDecision;
      nextPhase?: RehabPhase | null;
    }) => {
      const row = await db.sessions.get(args.id);
      if (!row) return;
      await db.sessions.put({
        ...row,
        response24h: args.response,
        decision: args.decision,
        resolvedAt: new Date().toISOString(),
        snoozedUntil: null,
        updatedAt: new Date().toISOString(),
      });
      if (args.nextPhase) {
        const current = (await db.settings.get("default")) ?? defaultSettings();
        await db.settings.put({
          ...current,
          currentPhase: args.nextPhase,
          phaseChangedAt: new Date().toISOString(),
        });
      }
      await refresh();
    },
    [refresh],
  );

  const snoozeSession = useCallback(
    async (id: string, untilIso: string) => {
      const row = await db.sessions.get(id);
      if (!row) return;
      await db.sessions.put({
        ...row,
        snoozedUntil: untilIso,
        snoozeUsed: true,
        updatedAt: new Date().toISOString(),
      });
      await refresh();
    },
    [refresh],
  );

  const updateSettings = useCallback(
    async (patch: Partial<AppSettings>) => {
      const current = (await db.settings.get("default")) ?? defaultSettings();
      const next: AppSettings = { ...current, ...patch, id: "default" };
      if (patch.currentPhase && patch.currentPhase !== current.currentPhase) {
        next.phaseChangedAt = new Date().toISOString();
      }
      await db.settings.put(next);
      await refresh();
    },
    [refresh],
  );

  const exportJson = useCallback(async () => {
    const data = await readAll();
    return serializeBackup(data);
  }, []);

  const importJson = useCallback(
    async (text: string, mode: "replace" | "merge") => {
      const incoming: BackupV2 = parseBackup(text);
      if (mode === "replace") {
        await db.transaction("rw", db.settings, db.checkIns, db.sessions, async () => {
          await db.checkIns.clear();
          await db.sessions.clear();
          await db.settings.put({ ...incoming.settings, id: "default" });
          if (incoming.dailyCheckIns.length) await db.checkIns.bulkPut(incoming.dailyCheckIns);
          if (incoming.trainingSessions.length) await db.sessions.bulkPut(incoming.trainingSessions);
        });
      } else {
        const local = await readAll();
        const merged = mergeBackup(local, incoming);
        await db.transaction("rw", db.settings, db.checkIns, db.sessions, async () => {
          await db.settings.put(merged.settings);
          await db.checkIns.clear();
          await db.sessions.clear();
          if (merged.checkIns.length) await db.checkIns.bulkPut(merged.checkIns);
          if (merged.sessions.length) await db.sessions.bulkPut(merged.sessions);
        });
      }
      await refresh();
    },
    [refresh],
  );

  const clearLogs = useCallback(async () => {
    await db.transaction("rw", db.checkIns, db.sessions, async () => {
      await db.checkIns.clear();
      await db.sessions.clear();
    });
    await refresh();
  }, [refresh]);

  const loadDemo = useCallback(async () => {
    const demo = buildDemoWeek();
    await db.transaction("rw", db.settings, db.checkIns, db.sessions, async () => {
      await db.checkIns.clear();
      await db.sessions.clear();
      await db.settings.put(demo.settings);
      await db.checkIns.bulkPut(demo.checkIns);
      await db.sessions.bulkPut(demo.sessions);
    });
    await refresh();
  }, [refresh]);

  const value = useMemo<StoreValue>(
    () => ({
      ready,
      settings,
      checkIns,
      sessions,
      refresh,
      upsertCheckIn,
      saveSession,
      deleteSession,
      deleteCheckIn,
      resolveSession,
      snoozeSession,
      updateSettings,
      exportJson,
      importJson,
      clearLogs,
      loadDemo,
    }),
    [
      ready,
      settings,
      checkIns,
      sessions,
      refresh,
      upsertCheckIn,
      saveSession,
      deleteSession,
      deleteCheckIn,
      resolveSession,
      snoozeSession,
      updateSettings,
      exportJson,
      importJson,
      clearLogs,
      loadDemo,
    ],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useStore(): StoreValue {
  const ctx = useContext(StoreContext);
  if (!ctx) throw new Error("useStore must be used within StoreProvider");
  return ctx;
}
