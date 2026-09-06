export const Colors = {
  bg: {
    primary: "#0A0F1E",
    card: "#131929",
    elevated: "#1A2540",
    input: "#0F1828",
  },
  accent: {
    teal: "#1D9E75",
    tealLight: "#9FE1CB",
    coral: "#D85A30",
    coralLight: "#F0997B",
    amber: "#BA7517",
    amberLight: "#FAC775",
    blue: "#378ADD",
    blueLight: "#B5D4F4",
    purple: "#7F77DD",
  },
  text: {
    primary: "#F0F4FF",
    secondary: "#8A9BC4",
    tertiary: "#4A5A80",
    inverse: "#0A0F1E",
  },
  border: "#1E2D4A",
  allergen: {
    confirmed: { bg: "#2D0A0A", border: "#A32D2D", text: "#FF9999" },
    probable: { bg: "#2D1A00", border: "#854F0B", text: "#FAC775" },
    safe: { bg: "#0A2D1A", border: "#0F6E56", text: "#9FE1CB" },
  },
  grade: {
    A: "#1D9E75",
    B: "#378ADD",
    C: "#BA7517",
    D: "#D85A30",
    F: "#A32D2D",
  },
} as const;

export type GradeLetter = keyof typeof Colors.grade;

export function scoreColor(score: number): string {
  if (score >= 75) return Colors.accent.teal;
  if (score >= 50) return Colors.accent.amber;
  return Colors.accent.coral;
}
