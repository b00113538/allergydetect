import Anthropic from "@anthropic-ai/sdk";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { ALLOWED_MEDIA_TYPES, ANTHROPIC_API_KEY, MAX_BASE64_LENGTH, MODEL, type MediaType } from "./claude";
import { LABEL_SCHEMA, LABEL_SYSTEM_PROMPT, cleanLabel, type ProductLabel } from "./labelLogic";

/**
 * Callable: photo of a product ingredient list or a clothing care label → transcribed ingredients
 * (JSON), via Claude vision with structured output. The app matches them against its on-device
 * contact-allergen list and the user reviews them before saving.
 * Request:  { imageBase64: string, mediaType: "image/jpeg" | "image/png" | "image/webp" }
 * Response: ProductLabel
 */
export const readProductLabel = onCall(
  { secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120, memory: "512MiB", region: "us-central1" },
  async (request): Promise<ProductLabel> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to read product labels.");
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
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        output_config: {
          // Small print, long chemical names: accuracy over speed.
          effort: "high",
          format: { type: "json_schema", schema: LABEL_SCHEMA },
        },
        system: LABEL_SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: mediaType as MediaType, data: imageBase64 } },
              { type: "text", text: "Transcribe the ingredients or fibre content on this label." },
            ],
          },
        ],
      });
    } catch (err) {
      if (err instanceof Anthropic.RateLimitError) {
        throw new HttpsError("resource-exhausted", "Too many requests — try again in a moment.");
      }
      if (err instanceof Anthropic.BadRequestError) {
        logger.error("Claude rejected the label image", { message: err.message });
        throw new HttpsError("invalid-argument", "That photo couldn't be read. Try a closer, sharper shot of the label.");
      }
      if (err instanceof Anthropic.APIError) {
        logger.error("Claude API error", { status: err.status, message: err.message });
        throw new HttpsError("unavailable", "Label reading is temporarily unavailable.");
      }
      throw err;
    }

    if (response.stop_reason === "refusal") {
      throw new HttpsError("failed-precondition", "This label couldn't be read. Please type the ingredients instead.");
    }
    if (response.stop_reason === "max_tokens") {
      throw new HttpsError("internal", "The label was cut short. Please try again.");
    }

    const text = response.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("");
    try {
      return cleanLabel(JSON.parse(text) as ProductLabel);
    } catch {
      logger.error("Unparseable label output", { text: text.slice(0, 500) });
      throw new HttpsError("internal", "The label came back in an unexpected format.");
    }
  },
);
