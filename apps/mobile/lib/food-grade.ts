import type { GradeLetter } from "@/types";

export function gradeFromScore(score: number): GradeLetter {
  if (score >= 85) return "A";
  if (score >= 70) return "B";
  if (score >= 55) return "C";
  if (score >= 40) return "D";
  return "F";
}

export const GRADE_LABELS: Record<GradeLetter, string> = {
  A: "Excellent",
  B: "Good",
  C: "Average",
  D: "Poor",
  F: "Avoid",
};

export const NOVA_LABELS: Record<number, string> = {
  1: "Unprocessed",
  2: "Processed culinary",
  3: "Processed",
  4: "Ultra-processed",
};
