import { defineSecret } from "firebase-functions/params";

// Shared by every function that calls Claude.
// Set with: firebase functions:secrets:set ANTHROPIC_API_KEY
export const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

export const MODEL = "claude-opus-5-5";
export const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type MediaType = (typeof ALLOWED_MEDIA_TYPES)[number];
// ~5 MB decoded; the app sends ≤1568px JPEGs, typically 200–600 KB.
export const MAX_BASE64_LENGTH = 7_000_000;
