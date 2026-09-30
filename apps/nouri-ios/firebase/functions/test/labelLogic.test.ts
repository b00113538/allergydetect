import { test } from "node:test";
import assert from "node:assert/strict";
import { cleanLabel } from "../src/labelLogic";

test("cleanLabel trims, dedupes case-insensitively and clamps percentages", () => {
  const cleaned = cleanLabel({
    productName: "  Brand X Daily Moisturiser ",
    kind: "product",
    ingredients: [
      { name: "Aqua", percent: -1 },
      { name: " Parfum.", percent: -1 },
      { name: "parfum", percent: -1 },
      { name: "", percent: -1 },
      { name: "Linalool   ", percent: 250 },
    ],
    notes: " ",
  });
  assert.equal(cleaned.productName, "Brand X Daily Moisturiser");
  assert.deepEqual(cleaned.ingredients, [
    { name: "Aqua", percent: -1 },
    { name: "Parfum", percent: -1 },
    { name: "Linalool", percent: -1 },
  ]);
  assert.equal(cleaned.notes, "");
});

test("cleanLabel keeps fabric percentages and falls back to product kind", () => {
  const fabric = cleanLabel({ productName: "", kind: "fabric", ingredients: [{ name: "Wool", percent: 80 }, { name: "Polyamide", percent: 20 }], notes: "" });
  assert.deepEqual(fabric.ingredients.map((i) => i.percent), [80, 20]);
  const odd = cleanLabel({ productName: "", kind: "gadget" as never, ingredients: [], notes: "" });
  assert.equal(odd.kind, "product");
});
