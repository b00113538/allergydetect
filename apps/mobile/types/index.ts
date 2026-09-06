export type GradeLetter = "A" | "B" | "C" | "D" | "F";
export type MealType = "breakfast" | "lunch" | "dinner" | "snack";
export type LogSource = "camera" | "barcode" | "manual" | "custom";

export interface User {
  id: string;
  email: string;
  name: string;
  dob?: string | null;
  biological_sex?: string | null;
  height_cm?: number | null;
  weight_kg?: number | null;
  activity_level: string;
  timezone: string;
  locale: string;
  avatar_url?: string | null;
  onboarding_complete: boolean;
  created_at?: string | null;
}

export interface Goal {
  id: string;
  goal_type: string;
  tdee_kcal?: number | null;
  calories_target?: number | null;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
  fiber_g?: number | null;
  water_ml: number;
  sodium_mg?: number | null;
}

export interface Allergy {
  id: string;
  allergen_name: string;
  allergen_category?: string | null;
  severity: string;
  confirmed_by_doctor: boolean;
}

export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  user: User;
}

export interface MeResponse {
  user: User;
  goals: Goal[];
  allergies: Allergy[];
}

export interface FoodLogItem {
  id?: string;
  ingredient_name: string;
  quantity_g: number;
  calories?: number | null;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
  fiber_g?: number | null;
  sugar_g?: number | null;
  sodium_mg?: number | null;
  saturated_fat_g?: number | null;
  food_grade?: string | null;
  allergen_flags: string[];
  confidence_score: number;
  nova_group?: number | null;
  nutriscore?: string | null;
}

export interface FoodLog {
  id: string;
  logged_at: string;
  meal_type: MealType;
  source: LogSource;
  food_image_url?: string | null;
  notes?: string | null;
  total_calories: number;
  meal_grade?: GradeLetter | null;
  items: FoodLogItem[];
}

export interface MacroTotals {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g: number;
  sodium_mg: number;
}

export interface GoalProgress {
  calories_pct: number;
  protein_pct: number;
  carbs_pct: number;
  fat_pct: number;
}

export interface DailyScores {
  meal_quality: number;
  eating_rhythm: number;
  diet_wholeness: number;
}

export interface TodayResponse {
  date: string;
  logs: FoodLog[];
  totals: MacroTotals;
  goal_progress: GoalProgress;
  daily_scores: DailyScores;
}

export interface CreateFoodLogRequest {
  meal_type: MealType;
  source: LogSource;
  food_image_url?: string;
  notes?: string;
  items: Omit<FoodLogItem, "id" | "food_grade">[];
  logged_at?: string;
}

export interface SymptomLog {
  id: string;
  logged_at: string;
  symptoms: string[];
  severity: number;
  notes?: string | null;
  linked_food_log_ids: string[];
  anaphylaxis_suspected: boolean;
}

export interface SymptomCreateResponse {
  symptom: SymptomLog;
  emergency_flag: boolean;
}

export interface AllergenCandidate {
  ingredient_name: string;
  confidence_score: number;
  symptom_exposure_count: number;
  total_exposure_count: number;
  avg_severity_when_exposed: number;
  label: string;
}

export interface AIInsight {
  id: string;
  insight_type: string;
  content: Record<string, unknown>;
  read: boolean;
  generated_at: string | null;
}

export interface ScanIngredient {
  name: string;
  confidence_score: number;
  quantity_estimate_g: number;
  is_allergen_candidate: boolean;
  common_allergen_category: string | null;
  calories_per_100g: number;
  protein_g_per_100g: number;
  carbs_g_per_100g: number;
  fat_g_per_100g: number;
  fiber_g_per_100g: number;
  sugar_g_per_100g: number;
}

export interface ScanAnalysis {
  identified_dishes: string[];
  ingredients: ScanIngredient[];
  total_macros: {
    calories: number;
    protein_g: number;
    carbs_g: number;
    fat_g: number;
    fiber_g: number;
    sugar_g: number;
  };
  portion_description: string;
  cuisine_type: string;
  allergen_flags: string[];
  processing_level: number;
}

export interface AllergenMatch {
  allergen: string;
  severity: string;
  confirmed_by_doctor: boolean;
  matched_flag: string;
  status: string;
}

export interface GradeResult {
  grade: GradeLetter;
  score: number;
  breakdown: Record<string, number>;
}

export interface CameraScanResult {
  image_url: string;
  analysis: ScanAnalysis;
  allergen_matches: AllergenMatch[];
  grade: GradeResult;
}

export interface BarcodeProduct {
  found: boolean;
  barcode: string;
  name?: string;
  brand?: string | null;
  image_url?: string | null;
  ingredients_text?: string | null;
  nutriscore?: string | null;
  nova_group?: number | null;
  allergens?: string[];
  macros_per_100g?: Record<string, number>;
  allergen_matches?: AllergenMatch[];
  grade?: GradeResult;
}

export interface StreakInfo {
  type: string;
  current: number;
  record: number;
}

export interface AllergyCard {
  target_language: string;
  language_name: string;
  allergen_statements: {
    allergen: string;
    translated_name: string;
    translated_statement: string;
  }[];
  emergency_phrase: string;
  full_card_text: string;
}
