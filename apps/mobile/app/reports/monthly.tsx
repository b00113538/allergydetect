import { useQuery } from "@tanstack/react-query";
import { ScrollView, StyleSheet, Text, View } from "react-native";

import { GradeDistributionPie } from "@/components/charts/GradeDistributionPie";
import { MacroTrendLine, type TrendPoint } from "@/components/charts/MacroTrendLine";
import { MacroBar } from "@/components/food/MacroBar";
import { Badge } from "@/components/ui/Badge";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { useWearableSummary } from "@/hooks/useWearables";
import { api } from "@/lib/api";

interface MonthlyReport {
  logging_consistency_pct: number;
  total_reactions: number;
  reaction_severity_avg: number;
  most_common_symptoms: { symptom: string; count: number }[];
  top_foods: { name: string; count: number; avg_grade: number }[];
  top_allergen_candidates: { name: string; confidence_score: number }[];
  macro_adherence: { protein_pct: number; carbs_pct: number; fat_pct: number; calories_pct: number };
  grade_distribution: Record<string, number>;
  reaction_free_days: number;
  food_group_breakdown?: { protein_sources: string[]; carb_sources: string[]; fat_sources: string[] };
}

interface WearableDaily {
  date: string;
  hrv?: number;
  heart_rate?: number;
  resting_hr?: number;
  sleep_score?: number;
}

export default function MonthlyReport() {
  const report = useQuery({
    queryKey: ["monthly-report"],
    queryFn: () => api.monthlyReport() as Promise<MonthlyReport>,
  });
  const wearables = useWearableSummary(30);
  const r = report.data;
  const daily = (wearables.data?.daily ?? []) as WearableDaily[];

  const hrvTrend: TrendPoint[] = daily.filter((d) => d.hrv != null).map((d) => ({ date: d.date, value: d.hrv ?? 0 }));
  const sleepTrend: TrendPoint[] = daily.filter((d) => d.sleep_score != null).map((d) => ({ date: d.date, value: d.sleep_score ?? 0 }));

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.h1}>Last 30 days</Text>

      <Card>
        <Text style={styles.big}>{r?.logging_consistency_pct ?? 0}%</Text>
        <Text style={styles.muted}>Logging consistency</Text>
      </Card>

      <Card>
        <Text style={styles.title}>Macro adherence (avg/day)</Text>
        <MacroBar label="Calories" value={r?.macro_adherence.calories_pct ?? 0} target={100} unit="%" color={Colors.accent.purple} />
        <MacroBar label="Protein" value={r?.macro_adherence.protein_pct ?? 0} target={100} unit="%" color={Colors.accent.teal} />
        <MacroBar label="Carbs" value={r?.macro_adherence.carbs_pct ?? 0} target={100} unit="%" color={Colors.accent.blue} />
        <MacroBar label="Fat" value={r?.macro_adherence.fat_pct ?? 0} target={100} unit="%" color={Colors.accent.amber} />
      </Card>

      <Card>
        <Text style={styles.title}>Grade distribution</Text>
        <GradeDistributionPie data={r?.grade_distribution ?? {}} />
      </Card>

      <Card>
        <Text style={styles.title}>Food group breakdown</Text>
        {r?.food_group_breakdown ? (
          <View style={{ gap: 10 }}>
            <View>
              <Text style={styles.sub}>Protein sources</Text>
              <View style={styles.chips}>
                {r.food_group_breakdown.protein_sources.map((n) => <Badge key={n} label={n} color={Colors.accent.teal} bg={`${Colors.accent.teal}20`} />)}
              </View>
            </View>
            <View>
              <Text style={styles.sub}>Carb sources</Text>
              <View style={styles.chips}>
                {r.food_group_breakdown.carb_sources.map((n) => <Badge key={n} label={n} color={Colors.accent.blue} bg={`${Colors.accent.blue}20`} />)}
              </View>
            </View>
            <View>
              <Text style={styles.sub}>Fat sources</Text>
              <View style={styles.chips}>
                {r.food_group_breakdown.fat_sources.map((n) => <Badge key={n} label={n} color={Colors.accent.amber} bg={`${Colors.accent.amber}20`} />)}
              </View>
            </View>
          </View>
        ) : (
          <Text style={styles.muted}>Log more meals to see your food-group mix.</Text>
        )}
      </Card>

      <Card>
        <Text style={styles.title}>Reactions</Text>
        <Text style={styles.muted}>Total: {r?.total_reactions ?? 0} · Avg severity {r?.reaction_severity_avg ?? 0}</Text>
        <Text style={styles.muted}>Reaction-free days: {r?.reaction_free_days ?? 0} / 30</Text>
      </Card>

      <Card>
        <Text style={styles.title}>Wearable trends</Text>
        <MacroTrendLine data={hrvTrend} color={Colors.accent.purple} label="HRV (ms)" />
        <View style={{ height: 8 }} />
        <MacroTrendLine data={sleepTrend} color={Colors.accent.blue} label="Sleep score" />
      </Card>

      <Card>
        <Text style={styles.title}>Top allergen candidates</Text>
        {(r?.top_allergen_candidates ?? []).length === 0 && <Text style={styles.muted}>None yet.</Text>}
        {(r?.top_allergen_candidates ?? []).map((c) => (
          <Text key={c.name} style={styles.muted}>
            {c.name} — {Math.round(c.confidence_score * 100)}%
          </Text>
        ))}
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  h1: { color: Colors.text.primary, fontSize: 22, fontWeight: "800" },
  big: { color: Colors.accent.teal, fontSize: 44, fontWeight: "800", textAlign: "center" },
  muted: { color: Colors.text.secondary, marginVertical: 2, textTransform: "capitalize" },
  title: { color: Colors.text.primary, fontWeight: "800", marginBottom: 8 },
  sub: { color: Colors.text.secondary, fontSize: 13, fontWeight: "600", marginBottom: 4 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
});
