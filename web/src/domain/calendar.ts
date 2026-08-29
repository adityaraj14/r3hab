export type DayCalendar = {
  startOfDay: (date: Date) => Date;
  dayKey: (date: Date) => string;
  addDays: (date: Date, n: number) => Date;
};

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

export const utcCalendar: DayCalendar = {
  startOfDay(date) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  },
  dayKey(date) {
    const d = utcCalendar.startOfDay(date);
    return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
  },
  addDays(date, n) {
    const d = utcCalendar.startOfDay(date);
    d.setUTCDate(d.getUTCDate() + n);
    return d;
  },
};

export const localCalendar: DayCalendar = {
  startOfDay(date) {
    const d = new Date(date.getTime());
    d.setHours(0, 0, 0, 0);
    return d;
  },
  dayKey(date) {
    const d = localCalendar.startOfDay(date);
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  },
  addDays(date, n) {
    const d = localCalendar.startOfDay(date);
    d.setDate(d.getDate() + n);
    return d;
  },
};

export function parseDayKey(dayKey: string, calendar: DayCalendar = localCalendar): Date {
  const [y, m, d] = dayKey.split("-").map(Number);
  if (calendar === utcCalendar) {
    return new Date(Date.UTC(y, m - 1, d));
  }
  return new Date(y, m - 1, d);
}

export function compareDayKeys(a: string, b: string): number {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

export function formatDayLabel(dayKey: string, todayKey: string): string {
  if (dayKey === todayKey) return "Today";
  const [y, m, d] = dayKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  return date.toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}
