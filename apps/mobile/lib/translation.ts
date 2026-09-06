import { api } from "@/lib/api";
import { offlineCache } from "@/lib/storage";
import type { AllergyCard } from "@/types";

export async function generateAllergyCard(
  allergens: string[],
  targetLanguage: string,
  severityByAllergen?: Record<string, string>
): Promise<AllergyCard> {
  const card = (await api.allergyCard(allergens, targetLanguage, severityByAllergen)) as AllergyCard;
  await offlineCache.setAllergyCard(targetLanguage, card);
  return card;
}

export async function getCachedCard(language: string): Promise<AllergyCard | null> {
  return (await offlineCache.allergyCard(language)) as AllergyCard | null;
}
