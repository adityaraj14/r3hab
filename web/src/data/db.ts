import Dexie, { type EntityTable } from "dexie";
import type { AppSettings, DailyCheckIn, TrainingSession } from "@/domain/types";

export class R3habDB extends Dexie {
  settings!: EntityTable<AppSettings, "id">;
  checkIns!: EntityTable<DailyCheckIn, "dayKey">;
  sessions!: EntityTable<TrainingSession, "id">;

  constructor() {
    super("r3hab");
    this.version(1).stores({
      settings: "id",
      checkIns: "dayKey, date",
      sessions: "id, date, response24h, createdAt",
    });
  }
}

export const db = new R3habDB();
