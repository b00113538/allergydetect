import axios, { AxiosError, AxiosInstance } from "axios";
import Constants from "expo-constants";

import type {
  AIInsight,
  Allergy,
  AllergenCandidate,
  AuthResponse,
  BarcodeProduct,
  CameraScanResult,
  CreateFoodLogRequest,
  FoodLog,
  Goal,
  MeResponse,
  SymptomCreateResponse,
  TodayResponse,
  User,
} from "@/types";
import { tokenStore } from "@/lib/storage";

const BASE_URL =
  (Constants.expoConfig?.extra?.apiBaseUrl as string | undefined) ??
  "http://localhost:8000/api/v1";

let onUnauthorized: (() => void) | null = null;
export function setUnauthorizedHandler(fn: () => void) {
  onUnauthorized = fn;
}

const client: AxiosInstance = axios.create({ baseURL: BASE_URL, timeout: 30000 });

client.interceptors.request.use(async (config) => {
  const token = await tokenStore.getAccess();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

let refreshing: Promise<string | null> | null = null;

async function refreshAccess(): Promise<string | null> {
  const refresh = await tokenStore.getRefresh();
  if (!refresh) return null;
  try {
    const res = await axios.post(`${BASE_URL}/auth/refresh`, { refresh_token: refresh });
    const access = res.data.access_token as string;
    await tokenStore.setAccess(access);
    return access;
  } catch {
    return null;
  }
}

client.interceptors.response.use(
  (r) => r,
  async (error: AxiosError) => {
    const original = error.config;
    if (error.response?.status === 401 && original && !(original as any)._retry) {
      (original as any)._retry = true;
      refreshing = refreshing ?? refreshAccess();
      const newToken = await refreshing;
      refreshing = null;
      if (newToken) {
        original.headers = original.headers ?? {};
        original.headers.Authorization = `Bearer ${newToken}`;
        return client(original);
      }
      await tokenStore.clear();
      onUnauthorized?.();
    }
    return Promise.reject(error);
  }
);

export const api = {
  // ---- auth ----
  async register(email: string, password: string, name: string): Promise<AuthResponse> {
    const { data } = await client.post<AuthResponse>("/auth/register", { email, password, name });
    await tokenStore.setTokens(data.access_token, data.refresh_token);
    return data;
  },
  async login(email: string, password: string): Promise<AuthResponse> {
    const { data } = await client.post<AuthResponse>("/auth/login", { email, password });
    await tokenStore.setTokens(data.access_token, data.refresh_token);
    return data;
  },
  async logout(): Promise<void> {
    const refresh = await tokenStore.getRefresh();
    if (refresh) {
      try {
        await client.post("/auth/logout", { refresh_token: refresh });
      } catch {
        /* ignore */
      }
    }
    await tokenStore.clear();
  },
  async me(): Promise<MeResponse> {
    const { data } = await client.get<MeResponse>("/auth/me");
    return data;
  },

  // ---- users / profile ----
  async updateProfile(payload: Partial<User>): Promise<User> {
    const { data } = await client.put<User>("/users/me", payload);
    return data;
  },
  async recommendMacros(goalType: string) {
    const { data } = await client.post("/users/me/recommend-macros", { goal_type: goalType });
    return data as { tdee_kcal: number; calories: number; protein_g: number; carbs_g: number; fat_g: number; fiber_g: number };
  },
  async upsertGoal(payload: Partial<Goal> & { goal_type: string }): Promise<Goal> {
    const { data } = await client.put<Goal>("/users/me/goals", payload);
    return data;
  },
  async listAllergies(): Promise<Allergy[]> {
    const { data } = await client.get<Allergy[]>("/users/me/allergies");
    return data;
  },
  async addAllergy(payload: { allergen_name: string; allergen_category?: string; severity: string; confirmed_by_doctor?: boolean }): Promise<Allergy> {
    const { data } = await client.post<Allergy>("/users/me/allergies", payload);
    return data;
  },
  async deleteAllergy(id: string): Promise<void> {
    await client.delete(`/users/me/allergies/${id}`);
  },

  // ---- food log ----
  async today(): Promise<TodayResponse> {
    const { data } = await client.get<TodayResponse>("/food-log/today");
    return data;
  },
  async createFoodLog(payload: CreateFoodLogRequest): Promise<FoodLog> {
    const { data } = await client.post<FoodLog>("/food-log", payload);
    return data;
  },
  async getFoodLog(id: string): Promise<FoodLog> {
    const { data } = await client.get<FoodLog>(`/food-log/${id}`);
    return data;
  },
  async deleteFoodLog(id: string): Promise<void> {
    await client.delete(`/food-log/${id}`);
  },
  async frequentIngredients() {
    const { data } = await client.get<{ ingredient_name: string; count: number }[]>("/food-log/frequent");
    return data;
  },

  // ---- scan ----
  async scanBarcode(barcode: string): Promise<BarcodeProduct> {
    const { data } = await client.post<BarcodeProduct>("/scan/barcode", { barcode });
    return data;
  },
  async scanText(query: string, quantity_g?: number) {
    const { data } = await client.post("/scan/text", { query, quantity_g });
    return data;
  },
  async scanCamera(imageUri: string): Promise<CameraScanResult> {
    const form = new FormData();
    form.append("image", {
      uri: imageUri,
      name: "scan.jpg",
      type: "image/jpeg",
    } as unknown as Blob);
    const { data } = await client.post<CameraScanResult>("/scan/camera", form, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data;
  },

  // ---- symptoms ----
  async createSymptom(payload: {
    symptoms: string[];
    severity: number;
    notes?: string;
    linked_food_log_ids?: string[];
    logged_at?: string;
  }): Promise<SymptomCreateResponse> {
    const { data } = await client.post<SymptomCreateResponse>("/symptoms", payload);
    return data;
  },
  async symptomWeeklySummary() {
    const { data } = await client.get("/symptoms/weekly-summary");
    return data as { daily: { date: string; count: number; avg_severity: number }[]; by_symptom: Record<string, number>; total: number; avg_severity: number };
  },
  async listSymptoms(params?: { limit?: number; offset?: number }) {
    const { data } = await client.get<import("@/types").SymptomLog[]>("/symptoms", { params });
    return data;
  },

  // ---- insights ----
  async allergenCandidates(): Promise<AllergenCandidate[]> {
    const { data } = await client.get<AllergenCandidate[]>("/insights/allergen-candidates");
    return data;
  },
  async recentInsights(): Promise<AIInsight[]> {
    const { data } = await client.get<AIInsight[]>("/insights/recent");
    return data;
  },
  async markInsightRead(id: string): Promise<void> {
    await client.post(`/insights/${id}/read`);
  },
  async triggerCorrelation() {
    const { data } = await client.post("/insights/trigger-correlation");
    return data as { count: number };
  },

  // ---- coach ----
  coachChatUrl(): string {
    return `${BASE_URL}/coach/chat`;
  },
  async dailyInsight(): Promise<{ insight: string }> {
    const { data } = await client.get<{ insight: string }>("/coach/daily-insight");
    return data;
  },

  // ---- reports ----
  async weeklyReport(weekStart?: string) {
    const { data } = await client.get("/reports/weekly", { params: { week_start: weekStart } });
    return data;
  },
  async monthlyReport(month?: string) {
    const { data } = await client.get("/reports/monthly", { params: { month } });
    return data;
  },
  async yearlyWrapped() {
    const { data } = await client.get("/reports/yearly-wrapped");
    return data;
  },

  // ---- wearables ----
  async syncWearables(source: string, readings: { metric: string; value: number; unit?: string; recorded_at: string }[]) {
    const { data } = await client.post("/wearables/sync", { source, readings });
    return data as { synced_count: number };
  },
  async wearableSummary(days = 7) {
    const { data } = await client.get("/wearables/summary", { params: { days } });
    return data;
  },
  async wearableReactionCorrelation() {
    const { data } = await client.get("/wearables/reaction-correlation");
    return data as { date: string; reaction: boolean; severity?: number; hrv_delta?: number | null; hr_delta?: number | null }[];
  },

  // ---- translation ----
  async allergyCard(allergens: string[], target_language: string, severity_by_allergen?: Record<string, string>) {
    const { data } = await client.post("/translation/allergy-card", {
      allergens,
      target_language,
      severity_by_allergen,
    });
    return data;
  },
  async languages() {
    const { data } = await client.get<{ code: string; name: string }[]>("/translation/languages");
    return data;
  },

  // ---- notifications ----
  async registerPushToken(expo_push_token: string, platform: string) {
    await client.post("/notifications/register-token", { expo_push_token, platform });
  },

  // ---- community ----
  async communityFeed(params?: { allergen_tag?: string; post_type?: string; limit?: number; offset?: number }) {
    const { data } = await client.get<CommunityPost[]>("/community/feed", { params });
    return data;
  },
  async createCommunityPost(payload: {
    post_type: string;
    title?: string;
    content: string;
    allergen_tags?: string[];
    is_anonymous?: boolean;
  }) {
    const { data } = await client.post<CommunityPost>("/community/posts", payload);
    return data;
  },
  async upvotePost(id: string) {
    const { data } = await client.post<CommunityPost>(`/community/posts/${id}/upvote`);
    return data;
  },
  async deletePost(id: string) {
    await client.delete(`/community/posts/${id}`);
  },
  async listRecipes(params?: { allergen_safe_for?: string; limit?: number; offset?: number }) {
    const { data } = await client.get<CommunityRecipe[]>("/community/recipes", { params });
    return data;
  },
  async createRecipe(payload: {
    name: string;
    ingredients: { name: string; quantity_g?: number; calories?: number; protein_g?: number; carbs_g?: number; fat_g?: number }[];
    allergen_tags?: string[];
    is_public?: boolean;
  }) {
    const { data } = await client.post<CommunityRecipe>("/community/recipes", payload);
    return data;
  },
};

export interface CommunityPost {
  id: string;
  post_type: string;
  title?: string | null;
  content: string;
  allergen_tags: string[];
  upvotes: number;
  is_anonymous: boolean;
  created_at: string;
}

export interface CommunityRecipe {
  id: string;
  name: string;
  ingredients: { name: string; quantity_g?: number; calories?: number; protein_g?: number; carbs_g?: number; fat_g?: number }[];
  macros: { calories?: number; protein_g?: number; carbs_g?: number; fat_g?: number };
  allergen_tags: string[];
  use_count: number;
  created_at: string;
}

export { client };
