import { useQuery } from "@tanstack/react-query";
import { ScrollView, StyleSheet, Text, View } from "react-native";

import { MacroBar } from "@/components/food/MacroBar";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";

interface WeeklyReport {
  logging_consistency_pct: number;
  total_reactions: number;
  reaction_severity_avg: number;
  most_common_symptoms: { symptom: string; count: number }[];
  top_foods: { name: string; count: number; avg_grade: number }[];
  macro_adherence: { protein_pct: number; carbs_pct: number; fat_pct: number; calories_pct: number };
  grade_distribution: Record<string, number>;
  reaction_free_days: number;
}

export default function WeeklyReport() {
  const report = useQuery({ queryKey: ["weekly-report"], queryFn: () => api.weeklyReport() as Promise<WeeklyReport> });
  const r = report.data;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card>
        <Text style={styles.big}>{r?.logging_consistency_pct ?? 0}%</Text>
        <Text style={styles.label}>Logging consistency</Text>
      </Card>

      <Card>
        <Text style={styles.title}>Macro adherence</Text>
        <MacroBar label="Calories" value={r?.macro_adherence.calories_pct ?? 0} target={100} unit="%" color={Colors.accent.purple} />
        <MacroBar label="Protein" value={r?.macro_adherence.protein_pct ?? 0} target={100} unit="%" color={Colors.accent.teal} />
        <MacroBar label="Carbs" value={r?.macro_adherence.carbs_pct ?? 0} target={100} unit="%" color={Colors.accent.blue} />
        <MacroBar label="Fat" value={r?.macro_adherence.fat_pct ?? 0} target={100} unit="%" color={Colors.accent.amber} />
      </Card>

      <Card>
        <Text style={styles.title}>Reactions</Text>
        <Text style={styles.detail}>Total: {r?.total_reactions ?? 0} · Avg severity {r?.reaction_severity_avg ?? 0}</Text>
        <Text style={styles.detail}>Reaction-free days: {r?.reaction_free_days ?? 0}</Text>
      </Card>

      <Card>
        <Text style={styles.title}>Grade distribution</Text>
        <View style={styles.gradeRow}>
          {(["A", "B", "C", "D", "F"] as const).map((g) => (
            <View key={g} style={styles.gradeCol}>
              <Text style={[styles.gradeLetter, { color: Colors.grade[g] }]}>{g}</Text>
              <Text style={styles.gradeCount}>{r?.grade_distribution?.[g] ?? 0}</Text>
            </View>
          ))}
        </View>
      </Card>

      <Card>
        <Text style={styles.title}>Top foods</Text>
        {r?.top_foods?.map((f) => (
          <Text key={f.name} style={styles.detail}>
            {f.name} · {f.count}×
          </Text>
        ))}
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  big: { color: Colors.accent.teal, fontSize: 44, fontWeight: "800", textAlign: "center" },
  label: { color: Colors.text.secondary, textAlign: "center" },
  title: { color: Colors.text.primary, fontWeight: "800", marginBottom: 8 },
  detail: { color: Colors.text.secondary, marginVertical: 2, textTransform: "capitalize" },
  gradeRow: { flexDirection: "row", justifyContent: "space-around" },
  gradeCol: { alignItems: "center" },
  gradeLetter: { fontSize: 22, fontWeight: "800" },
  gradeCount: { color: Colors.text.secondary, marginTop: 4 },
});
