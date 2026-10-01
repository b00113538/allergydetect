import { test } from "node:test";
import assert from "node:assert/strict";
import { consume, limitMessage, planFor, refund, utcDay } from "../src/quotaLogic";

const morning = new Date("2026-10-01T08:00:00Z");
const evening = new Date("2026-10-01T23:59:00Z");
const nextDay = new Date("2026-10-02T00:01:00Z");

test("allows up to the limit, then refuses", () => {
  let state = undefined;
  for (let i = 1; i <= 3; i++) {
    const d = consume(state, "report", 3, morning);
    assert.equal(d.allowed, true);
    assert.equal(d.remaining, 3 - i);
    state = d.next;
  }
  const blocked = consume(state, "report", 3, evening);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.remaining, 0);
  assert.deepEqual(blocked.next, state); // nothing written past the limit
});

test("kinds are counted separately", () => {
  const a = consume(undefined, "mealPhoto", 1, morning);
  const b = consume(a.next, "label", 1, morning);
  assert.equal(b.allowed, true);
  assert.equal(consume(b.next, "mealPhoto", 1, morning).allowed, false);
});

test("counts reset on a new UTC day", () => {
  const full = consume(undefined, "label", 1, evening).next;
  assert.equal(consume(full, "label", 1, evening).allowed, false);
  const fresh = consume(full, "label", 1, nextDay);
  assert.equal(fresh.allowed, true);
  assert.equal(fresh.next.day, "2026-10-02");
});

test("refund gives one back, never below zero, and ignores old days", () => {
  const used = consume(consume(undefined, "mealPhoto", 5, morning).next, "mealPhoto", 5, morning).next;
  assert.equal(refund(used, "mealPhoto", morning)?.counts.mealPhoto, 1);
  assert.equal(refund({ day: utcDay(morning), counts: {} }, "label", morning)?.counts.label, 0);
  assert.deepEqual(refund(used, "mealPhoto", nextDay), used); // yesterday's counts are left alone
  assert.equal(refund(undefined, "mealPhoto", morning), undefined);
});

test("limit message names the fallback", () => {
  assert.match(limitMessage("mealPhoto", 12), /12 meal photos.*typing the ingredients/);
  assert.match(limitMessage("report", 3), /3 report uploads.*by hand/);
});

test("plan comes only from the premium custom claim", () => {
  assert.equal(planFor({ plan: "premium" }), "premium");
  assert.equal(planFor({ plan: "PREMIUM" }), "free");
  assert.equal(planFor({}), "free");
  assert.equal(planFor(undefined), "free");
});
