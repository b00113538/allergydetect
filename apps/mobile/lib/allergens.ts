import type { Allergy } from "@/types";

const ALLERGEN_FAMILIES: Record<string, string[]> = {
  shrimp: ["lobster", "crab", "crayfish", "prawn", "crustacean"],
  crab: ["lobster", "shrimp", "crustacean"],
  milk: ["casein", "whey", "lactose", "butter", "cream", "cheese"],
  gluten: ["wheat", "barley", "rye", "malt", "spelt"],
  wheat: ["gluten", "barley", "rye"],
  peanut: ["groundnut", "arachis"],
  soy: ["soybean", "edamame", "tofu", "miso"],
  egg: ["albumin", "mayonnaise"],
};

function norm(s: string): string {
  return s.trim().toLowerCase();
}

export function expandTerms(allergen: string): string[] {
  const a = norm(allergen);
  return [a, ...(ALLERGEN_FAMILIES[a] ?? []).map(norm)];
}

export type AllergenStatus = "confirmed" | "probable" | "safe";

export function matchStatus(flags: string[], allergies: Allergy[]): AllergenStatus {
  const normFlags = flags.map(norm);
  for (const allergy of allergies) {
    const terms = expandTerms(allergy.allergen_name);
    for (const flag of normFlags) {
      if (terms.some((t) => t && (flag.includes(t) || t.includes(flag)))) {
        return "confirmed";
      }
    }
  }
  return flags.length > 0 ? "probable" : "safe";
}
