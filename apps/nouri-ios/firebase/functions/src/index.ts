import Anthropic from "@anthropic-ai/sdk";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { ALLOWED_MEDIA_TYPES, ANTHROPIC_API_KEY, MAX_BASE64_LENGTH, MODEL, type MediaType } from "./claude";

// Push notifications: evening reminder + weekly summary (see push.ts).
export { sendScheduledPushes } from "./push";
// In-app account deletion (App Store guideline 5.1.1(v)); see account.ts.
export { deleteAccount } from "./account";
// Phase 6+: skin product / clothing label reading; see label.ts.
export { readProductLabel } from "./label";

const SYSTEM_PROMPT = `You identify the ingredients in photos of meals for a food-allergy tracking app.
The user's list is used to correlate foods with symptoms, so include ingredients that are likely present even if not directly visible — sauces, dressings, oils, butter, breading, marinades, typical seasonings — when the dish strongly implies them. Mark those with visible=false and a lower confidence.
Use plain, specific ingredient names (e.g. "parmesan cheese", "wheat flour tortilla", "sesame oil"), one ingredient per entry, no quantities. Aim for 3–15 entries.
Confidence is your probability (0 to 1) that the ingredient is in this dish.
If the image does not show food, return an empty ingredients list and explain in notes.`;

const MEAL_SCHEMA = {
  type: "object",
  properties: {
    dishName: { type: "string", description: "Short common name of the dish" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          confidence: { type: "number" },
          visible: { type: "boolean" },
        },
        required: ["name", "confidence", "visible"],
        additionalProperties: false,
      },
    },
    notes: { type: "string", description: "Anything uncertain, or empty" },
  },
  required: ["dishName", "ingredients", "notes"],
  additionalProperties: false,
} as const;

interface MealAnalysis {
  dishName: string;
  ingredients: { name: string; confidence: number; visible: boolean }[];
  notes: string;
}

/**
 * Callable: meal photo → likely ingredients (JSON), via Claude vision with structured output.
 * Request:  { imageBase64: string, mediaType: "image/jpeg" | "image/png" | "image/webp" }
 * Response: MealAnalysis
 */
export const analyzeMealPhoto = onCall(
  { secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120, memory: "512MiB", region: "us-central1" },
  async (request): Promise<MealAnalysis> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to analyse meal photos.");
    }
    const { imageBase64, mediaType } = (request.data ?? {}) as { imageBase64?: unknown; mediaType?: unknown };
    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      throw new HttpsError("invalid-argument", "imageBase64 is required.");
    }
    if (imageBase64.length > MAX_BASE64_LENGTH) {
      throw new HttpsError("invalid-argument", "Image is too large.");
    }
    if (typeof mediaType !== "string" || !ALLOWED_MEDIA_TYPES.includes(mediaType as MediaType)) {
      throw new HttpsError("invalid-argument", "Unsupported image type.");
    }

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    let response;
    try {
      response = await client.beta.messages.create({
        model: MODEL,
        max_tokens: 16000,
        // Server-side refusal fallback: a declined request is retried on Anthropic's recommended model.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        output_config: {
          effort: "medium",
          format: { type: "json_schema", schema: MEAL_SCHEMA },
        },
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: mediaType as MediaType, data: imageBase64 } },
              { type: "text", text: "List the likely ingredients in this meal." },
            ],
          },
        ],
      });
    } catch (err) {
      if (err instanceof Anthropic.RateLimitError) {
        throw new HttpsError("resource-exhausted", "Too many requests — try again in a moment.");
      }
      if (err instanceof Anthropic.BadRequestError) {
        logger.error("Claude rejected the request", { message: err.message });
        throw new HttpsError("invalid-argument", "That image couldn't be processed.");
      }
      if (err instanceof Anthropic.APIError) {
        logger.error("Claude API error", { status: err.status, message: err.message });
        throw new HttpsError("unavailable", "Ingredient recognition is temporarily unavailable.");
      }
      throw err;
    }

    if (response.stop_reason === "refusal") {
      throw new HttpsError("failed-precondition", "This photo couldn't be analysed. Please enter ingredients manually.");
    }
    if (response.stop_reason === "max_tokens") {
      throw new HttpsError("internal", "The analysis was cut short. Please try again.");
    }

    const text = response.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("");
    let parsed: MealAnalysis;
    try {
      parsed = JSON.parse(text) as MealAnalysis;
    } catch {
      logger.error("Unparseable model output", { text: text.slice(0, 500) });
      throw new HttpsError("internal", "The analysis came back in an unexpected format.");
    }

    return {
      dishName: parsed.dishName.trim(),
      notes: parsed.notes.trim(),
      ingredients: parsed.ingredients
        .filter((i) => i.name.trim().length > 0)
        .map((i) => ({ name: i.name.trim(), confidence: Math.min(1, Math.max(0, i.confidence)), visible: i.visible })),
    };
  },
);

// ---------------------------------------------------------------------------------------------
// Phase 6: blood work upload → allergy panel extraction.

const REPORT_MEDIA_TYPES = [...ALLOWED_MEDIA_TYPES, "application/pdf"] as const;
type ReportMediaType = (typeof REPORT_MEDIA_TYPES)[number];
// ~10 MB decoded, matching the Storage upload limit.
const MAX_REPORT_BASE64_LENGTH = 14_000_000;

const BLOODWORK_SYSTEM_PROMPT = `You read allergy blood test reports (specific IgE panels such as ImmunoCAP) for an allergy-tracking app.
Extract every allergen-specific IgE result exactly as reported. Do not include total IgE, tryptase, or non-allergy tests; put a short mention of those in notes if present.
Use the allergen's plain name as printed (e.g. "Cow's milk", "Peanut", "Egg white", "Dermatophagoides pteronyssinus"). Include the lab's allergen code in parentheses only if there is no name.
value is the numeric result. If the report shows a bound such as "<0.10" or ">100", put the number in value and the symbol in comparator; otherwise comparator is "=".
unit is the unit as printed (usually kU/L, kUA/L or IU/mL).
reportedClass is the class the report states (0–6), or -1 if it states none. Never compute a class yourself.
testDate is the sample collection date in YYYY-MM-DD, or the report date if no collection date is shown, or "" if neither is legible.
If the document is not an allergy blood test, return an empty results list and say so in notes.`;

const BLOODWORK_SCHEMA = {
  type: "object",
  properties: {
    testDate: { type: "string", description: "YYYY-MM-DD, or empty" },
    labName: { type: "string", description: "Laboratory or clinic name, or empty" },
    results: {
      type: "array",
      items: {
        type: "object",
        properties: {
          allergen: { type: "string" },
          value: { type: "number" },
          comparator: { type: "string", enum: ["<", ">", "="] },
          unit: { type: "string" },
          reportedClass: { type: "integer" },
        },
        required: ["allergen", "value", "comparator", "unit", "reportedClass"],
        additionalProperties: false,
      },
    },
    notes: { type: "string", description: "Anything illegible, ambiguous or excluded, or empty" },
  },
  required: ["testDate", "labName", "results", "notes"],
  additionalProperties: false,
} as const;

interface BloodworkExtraction {
  testDate: string;
  labName: string;
  results: { allergen: string; value: number; comparator: "<" | ">" | "="; unit: string; reportedClass: number }[];
  notes: string;
}

/**
 * Callable: lab report (PDF or photo) → specific-IgE results (JSON), via Claude with structured output.
 * Request:  { documentBase64: string, mediaType: "application/pdf" | "image/jpeg" | "image/png" | "image/webp" }
 * Response: BloodworkExtraction
 * The user reviews and edits every row in the app before anything is saved.
 */
export const extractBloodworkPanel = onCall(
  { secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 300, memory: "1GiB", region: "us-central1" },
  async (request): Promise<BloodworkExtraction> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to upload blood work.");
    }
    const { documentBase64, mediaType } = (request.data ?? {}) as { documentBase64?: unknown; mediaType?: unknown };
    if (typeof documentBase64 !== "string" || documentBase64.length === 0) {
      throw new HttpsError("invalid-argument", "documentBase64 is required.");
    }
    if (documentBase64.length > MAX_REPORT_BASE64_LENGTH) {
      throw new HttpsError("invalid-argument", "The report is too large (10 MB max).");
    }
    if (typeof mediaType !== "string" || !REPORT_MEDIA_TYPES.includes(mediaType as ReportMediaType)) {
      throw new HttpsError("invalid-argument", "Upload a PDF or a photo of the report.");
    }

    const source =
      mediaType === "application/pdf"
        ? ({ type: "document", source: { type: "base64", media_type: "application/pdf", data: documentBase64 } } as const)
        : ({ type: "image", source: { type: "base64", media_type: mediaType as MediaType, data: documentBase64 } } as const);

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    let response;
    try {
      // Streamed: multi-page reports can take a while, and streaming avoids HTTP timeouts.
      response = await client.beta.messages
        .stream({
          model: MODEL,
          max_tokens: 32000,
          betas: ["server-side-fallback-2026-07-01"],
          fallbacks: "default",
          output_config: {
            // Transcribing numbers accurately matters more than latency here.
            effort: "high",
            format: { type: "json_schema", schema: BLOODWORK_SCHEMA },
          },
          system: BLOODWORK_SYSTEM_PROMPT,
          messages: [
            {
              role: "user",
              content: [source, { type: "text", text: "Extract the allergen-specific IgE results from this report." }],
            },
          ],
        })
        .finalMessage();
    } catch (err) {
      if (err instanceof Anthropic.RateLimitError) {
        throw new HttpsError("resource-exhausted", "Too many requests — try again in a moment.");
      }
      if (err instanceof Anthropic.BadRequestError) {
        logger.error("Claude rejected the report", { message: err.message });
        throw new HttpsError("invalid-argument", "That document couldn't be read. Try a clearer photo or the original PDF.");
      }
      if (err instanceof Anthropic.APIError) {
        logger.error("Claude API error", { status: err.status, message: err.message });
        throw new HttpsError("unavailable", "Report reading is temporarily unavailable.");
      }
      throw err;
    }

    if (response.stop_reason === "refusal") {
      throw new HttpsError("failed-precondition", "This document couldn't be read. Please enter the results manually.");
    }
    if (response.stop_reason === "max_tokens") {
      throw new HttpsError("internal", "The report was too long to read in one go. Try uploading fewer pages.");
    }

    const text = response.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("");
    let parsed: BloodworkExtraction;
    try {
      parsed = JSON.parse(text) as BloodworkExtraction;
    } catch {
      logger.error("Unparseable model output", { text: text.slice(0, 500) });
      throw new HttpsError("internal", "The report came back in an unexpected format.");
    }

    return {
      testDate: /^\d{4}-\d{2}-\d{2}$/.test(parsed.testDate.trim()) ? parsed.testDate.trim() : "",
      labName: parsed.labName.trim(),
      notes: parsed.notes.trim(),
      results: parsed.results
        .filter((r) => r.allergen.trim().length > 0 && Number.isFinite(r.value) && r.value >= 0)
        .map((r) => ({
          allergen: r.allergen.trim(),
          value: r.value,
          comparator: r.comparator,
          unit: r.unit.trim(),
          reportedClass: Number.isInteger(r.reportedClass) && r.reportedClass >= 0 && r.reportedClass <= 6 ? r.reportedClass : -1,
        })),
    };
  },
);
