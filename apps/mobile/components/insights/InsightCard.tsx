import { StyleSheet, Text } from "react-native";

import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Colors } from "@/constants/colors";
import type { AIInsight } from "@/types";

const TYPE_LABELS: Record<string, string> = {
  allergen_correlation: "Allergen pattern",
  elimination_suggestion: "Elimination",
  coach_tip: "Coach tip",
  weekly_report: "Weekly report",
};

export function InsightCard({ insight }: { insight: AIInsight }) {
  const top = (insight.content?.top_candidates as { ingredient_name: string; confidence_score: number }[] | undefined)?.[0];
  const body = top
    ? `${top.ingredient_name} is your strongest suspected trigger (${Math.round(top.confidence_score * 100)}%).`
    : "New insight available based on your latest logs.";

  return (
    <Card style={styles.card}>
      <Badge label={TYPE_LABELS[insight.insight_type] ?? insight.insight_type} bg={Colors.bg.elevated} color={Colors.accent.tealLight} />
      <Text style={styles.body}>{body}</Text>
      {insight.generated_at && (
        <Text style={styles.date}>{new Date(insight.generated_at).toLocaleDateString()}</Text>
      )}
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { marginBottom: 10 },
  body: { color: Colors.text.primary, fontSize: 14, marginTop: 8, lineHeight: 20 },
  date: { color: Colors.text.tertiary, fontSize: 11, marginTop: 6 },
});
