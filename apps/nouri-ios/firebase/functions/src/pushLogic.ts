// Pure helpers for the push-notification jobs — no Firebase imports, so they're unit-testable.

/** users/{uid}/devices/{fcmToken}, written by the app (see PushService.swift). */
export interface DeviceDoc {
  platform: string;
  /** Minutes east of UTC at the time the app last ran (refreshed on every launch, so DST is picked up). */
  utcOffsetMinutes: number;
  /** Local hour (0–23) the user picked for the evening reminder. */
  reminderHour: number;
  /** `reminderHour` converted to UTC — what the hourly job queries on. */
  reminderUtcHour: number;
  dailyReminder: boolean;
  weeklySummary: boolean;
}

export type Route = "logMeal" | "insights";

export interface PushMessage {
  title: string;
  body: string;
  route: Route;
}

const MINUTE = 60_000;
const DAY = 24 * 60 * MINUTE;

/** UTC hour at which a local `hour` occurs for a device `offsetMinutes` east of UTC. */
export function reminderUtcHour(hour: number, offsetMinutes: number): number {
  const minutes = (((hour * 60 - offsetMinutes) % 1440) + 1440) % 1440;
  return Math.floor(minutes / 60);
}

/** Midnight at the start of the device's local day, as an absolute instant. */
export function startOfLocalDay(now: Date, offsetMinutes: number): Date {
  const offset = offsetMinutes * MINUTE;
  return new Date(Math.floor((now.getTime() + offset) / DAY) * DAY - offset);
}

/** 0 = Sunday … 6 = Saturday, in the device's local time. */
export function localWeekday(now: Date, offsetMinutes: number): number {
  return new Date(now.getTime() + offsetMinutes * MINUTE).getUTCDay();
}

export function dailyReminderMessage(): PushMessage {
  return {
    title: "Nothing logged today",
    body: "A quick photo of today's meals — and how you felt — keeps your insights accurate.",
    route: "logMeal",
  };
}

export interface WeeklyStats {
  mealsLogged: number;
  reactions: number;
  /** Highest-confidence likely trigger, if any (e.g. "Dairy"). */
  topTrigger?: string;
  likelyTriggerCount: number;
}

export function weeklySummaryMessage(stats: WeeklyStats): PushMessage {
  const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? "" : "s"}`;
  let body = `This week: ${plural(stats.mealsLogged, "meal")} logged, ${plural(stats.reactions, "reaction")}.`;
  if (stats.topTrigger) {
    body += ` ${stats.topTrigger} is your strongest likely trigger`;
    body += stats.likelyTriggerCount > 1 ? ` (${stats.likelyTriggerCount} flagged in total).` : ".";
  } else if (stats.mealsLogged < 7) {
    body += " Log a few more meals to start seeing patterns.";
  } else {
    body += " No clear triggers yet — keep going.";
  }
  return { title: "Your week with Nouri", body, route: "insights" };
}

/** Likely-trigger names from a stored AllergyProfile, allergen groups first, strongest first. */
export function likelyTriggers(profile: unknown): string[] {
  const p = (profile ?? {}) as {
    triggerGroups?: { ingredient?: string; status?: string; confidence?: number }[];
    triggerIngredients?: { ingredient?: string; status?: string; confidence?: number }[];
  };
  const pick = (list: typeof p.triggerGroups) =>
    (list ?? [])
      .filter((t) => t.status === "likely" && typeof t.ingredient === "string")
      .sort((a, b) => (b.confidence ?? 0) - (a.confidence ?? 0))
      .map((t) => t.ingredient as string);
  const names = [...pick(p.triggerGroups), ...pick(p.triggerIngredients)];
  return names
    .map((n) => n.charAt(0).toUpperCase() + n.slice(1))
    .filter((n, i, all) => all.findIndex((m) => m.toLowerCase() === n.toLowerCase()) === i);
}

/** A symptom log counts as a reaction unless it only says "none". */
export function isReaction(symptomTypes: unknown): boolean {
  return Array.isArray(symptomTypes) && symptomTypes.some((t) => t !== "none");
}
