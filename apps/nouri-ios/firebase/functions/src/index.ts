import Anthropic from "@anthropic-ai/sdk";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";

// Set with: firebase functions:secrets:set ANTHROPIC_API_KEY
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const MODEL = "claude-opus-5-5";
const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
type MediaType = (typeof ALLOWED_MEDIA_TYPES)[number];
// ~5 MB decoded; the app sends ≤1568px JPEGs, typically 200–600 KB.
const MAX_BASE64_LENGTH = 7_000_000;

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
