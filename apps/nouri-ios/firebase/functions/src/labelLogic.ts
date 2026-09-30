// Pure helpers for readProductLabel — no Firebase/Anthropic imports, so they're unit-testable.

export type LabelKind = "product" | "fabric" | "material";

export interface ProductLabel {
  productName: string;
  kind: LabelKind;
  /** Ingredients / fibres in label order. `percent` is -1 when the label gives none. */
  ingredients: { name: string; percent: number }[];
  notes: string;
}

export const LABEL_SCHEMA = {
  type: "object",
  properties: {
    productName: { type: "string", description: "Brand and product as printed, or a short description; empty if not visible" },
    kind: { type: "string", enum: ["product", "fabric", "material"] },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          percent: { type: "number" },
        },
        required: ["name", "percent"],
        additionalProperties: false,
      },
    },
    notes: { type: "string", description: "Anything illegible, cut off or uncertain, or empty" },
  },
  required: ["productName", "kind", "ingredients", "notes"],
  additionalProperties: false,
} as const;

export const LABEL_SYSTEM_PROMPT = `You transcribe product labels for an app that tracks skin reactions.
The photo shows either a cosmetic or household product's ingredient list (kind "product"), a clothing or textile care label with fibre content (kind "fabric"), or packaging for another item such as jewellery, gloves or a watch strap (kind "material").
Copy every ingredient or fibre exactly as printed, in label order, one per entry — INCI names as written (e.g. "Methylchloroisothiazolinone", "Parfum", "Linalool"). Split "and"/"&"/"/"-joined items only when they are clearly separate ingredients. Do not translate, explain, or add ingredients that are not printed.
For fabric labels, put the fibre in name and its percentage in percent; otherwise percent is -1. If a garment lists several parts (shell, lining), include each fibre once with the shell's percentage and mention the rest in notes.
If the ingredient list is not visible (for example the front of the pack), return an empty list and say in notes that the ingredients side is needed.`;

/** Trims, drops empties and duplicates (case-insensitive), and clamps percentages. */
export function cleanLabel(raw: ProductLabel): ProductLabel {
  const seen = new Set<string>();
  const ingredients = raw.ingredients
    .map((i) => ({
      name: i.name.replace(/\s+/g, " ").trim().replace(/[.,;:]+$/, ""),
      percent: Number.isFinite(i.percent) && i.percent >= 0 && i.percent <= 100 ? i.percent : -1,
    }))
    .filter((i) => {
      const key = i.name.toLowerCase();
      if (key.length === 0 || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  const kind: LabelKind = ["product", "fabric", "material"].includes(raw.kind) ? raw.kind : "product";
  return { productName: raw.productName.trim(), kind, ingredients, notes: raw.notes.trim() };
}
