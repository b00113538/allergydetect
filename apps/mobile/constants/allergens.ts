export interface AllergenOption {
  name: string;
  category: string;
}

// EU Big-14 + FDA Big-9 master list.
export const ALLERGEN_MASTER_LIST: AllergenOption[] = [
  { name: "gluten", category: "cereals" },
  { name: "wheat", category: "cereals" },
  { name: "crustaceans", category: "seafood" },
  { name: "shellfish", category: "seafood" },
  { name: "molluscs", category: "seafood" },
  { name: "fish", category: "seafood" },
  { name: "eggs", category: "animal" },
  { name: "milk", category: "animal" },
  { name: "peanuts", category: "legumes" },
  { name: "soybeans", category: "legumes" },
  { name: "lupin", category: "legumes" },
  { name: "tree nuts", category: "nuts" },
  { name: "sesame", category: "seeds" },
  { name: "mustard", category: "seeds" },
  { name: "celery", category: "vegetables" },
  { name: "sulphites", category: "additives" },
];

export const SEVERITY_LEVELS = ["mild", "moderate", "severe", "anaphylactic"] as const;
export type Severity = (typeof SEVERITY_LEVELS)[number];
