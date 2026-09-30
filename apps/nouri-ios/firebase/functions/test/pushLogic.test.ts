import { test } from "node:test";
import assert from "node:assert/strict";
import {
  isReaction,
  likelyTriggers,
  localWeekday,
  reminderUtcHour,
  startOfLocalDay,
  weeklySummaryMessage,
} from "../src/pushLogic";

test("reminderUtcHour converts local hour using the device offset", () => {
  assert.equal(reminderUtcHour(20, 0), 20);
  assert.equal(reminderUtcHour(20, 240), 16); // Dubai, UTC+4
  assert.equal(reminderUtcHour(20, -300), 1); // New York winter, wraps to next UTC day
  assert.equal(reminderUtcHour(20, 330), 14); // India, UTC+5:30 → 14:30 UTC, runs at 14:00
  assert.equal(reminderUtcHour(1, 240), 21); // wraps to previous UTC day
});

test("startOfLocalDay honours the offset", () => {
  const now = new Date("2026-03-14T22:30:00Z");
  assert.equal(startOfLocalDay(now, 0).toISOString(), "2026-03-14T00:00:00.000Z");
  // 02:30 on the 15th in Dubai → local midnight is 20:00Z on the 14th.
  assert.equal(startOfLocalDay(now, 240).toISOString(), "2026-03-14T20:00:00.000Z");
  // 17:30 on the 14th in New York (UTC-5) → 05:00Z on the 14th.
  assert.equal(startOfLocalDay(now, -300).toISOString(), "2026-03-14T05:00:00.000Z");
});

test("localWeekday uses local date", () => {
  const saturdayNightUtc = new Date("2026-03-14T22:00:00Z"); // Saturday in UTC
  assert.equal(localWeekday(saturdayNightUtc, 0), 6);
  assert.equal(localWeekday(saturdayNightUtc, 240), 0); // already Sunday in Dubai
});

test("likelyTriggers prefers groups, sorts by confidence, dedupes", () => {
  const profile = {
    triggerGroups: [
      { ingredient: "Shellfish", status: "likely", confidence: 0.6 },
      { ingredient: "Dairy", status: "likely", confidence: 0.9 },
      { ingredient: "Gluten", status: "watching", confidence: 0.5 },
    ],
    triggerIngredients: [
      { ingredient: "parmesan cheese", status: "likely", confidence: 0.95 },
      { ingredient: "dairy", status: "likely", confidence: 0.5 },
    ],
  };
  assert.deepEqual(likelyTriggers(profile), ["Dairy", "Shellfish", "Parmesan cheese"]);
  assert.deepEqual(likelyTriggers(undefined), []);
});

test("isReaction ignores 'none'-only logs", () => {
  assert.equal(isReaction(["none"]), false);
  assert.equal(isReaction(["cough", "mucus"]), true);
  assert.equal(isReaction(undefined), false);
});

test("weekly summary wording", () => {
  assert.equal(
    weeklySummaryMessage({ mealsLogged: 1, reactions: 1, likelyTriggerCount: 0 }).body,
    "This week: 1 meal logged, 1 reaction. Log a few more meals to start seeing patterns.",
  );
  const withTrigger = weeklySummaryMessage({ mealsLogged: 18, reactions: 6, topTrigger: "Dairy", likelyTriggerCount: 3 });
  assert.equal(withTrigger.body, "This week: 18 meals logged, 6 reactions. Dairy is your strongest likely trigger (3 flagged in total).");
  assert.equal(withTrigger.route, "insights");
});
