const ACTIVITY_MULTIPLIERS: Record<string, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

const MACRO_SPLITS: Record<string, { protein: number; fat: number; carbs: number; deficit: number }> = {
  lose_fat: { protein: 0.35, fat: 0.3, carbs: 0.35, deficit: -500 },
  maintain: { protein: 0.3, fat: 0.3, carbs: 0.4, deficit: 0 },
  gain_muscle: { protein: 0.35, fat: 0.25, carbs: 0.4, deficit: 300 },
  manage_allergies: { protein: 0.3, fat: 0.3, carbs: 0.4, deficit: 0 },
  general_wellness: { protein: 0.25, fat: 0.3, carbs: 0.45, deficit: 0 },
};

export function calculateAge(dob?: string | null): number {
  if (!dob) return 30;
  const d = new Date(dob);
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age--;
  return age;
}

export function calculateTdee(
  weightKg: number,
  heightCm: number,
  ageYears: number,
  sex: string,
  activity: string
): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  const bmr = sex.toLowerCase().startsWith("m") ? base + 5 : base - 161;
  return Math.round(bmr * (ACTIVITY_MULTIPLIERS[activity] ?? 1.55));
}

export function recommendMacros(tdee: number, goalType: string) {
  const split = MACRO_SPLITS[goalType] ?? MACRO_SPLITS.maintain;
  const calories = tdee + split.deficit;
  return {
    calories,
    protein_g: Math.round((calories * split.protein) / 4),
    carbs_g: Math.round((calories * split.carbs) / 4),
    fat_g: Math.round((calories * split.fat) / 9),
  };
}
