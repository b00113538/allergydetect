import { ScrollView, StyleSheet, Text, View } from "react-native";

import { useQuery } from "@tanstack/react-query";

import { ConfidenceBar } from "@/components/insights/ConfidenceBar";
import { InsightCard } from "@/components/insights/InsightCard";
import { WearableCorrelation } from "@/components/insights/WearableCorrelation";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { useAllergenCandidates, useRecentInsights } from "@/hooks/useInsights";
import { useInsightsStore } from "@/store/insights";
import { api } from "@/lib/api";
import { scheduleEliminationReminder } from "@/lib/notifications";

export default function Insights() {
  const candidates = useAllergenCandidates();
  const insights = useRecentInsights();
  const correlation = useQuery({ queryKey: ["wearable-correlation"], queryFn: () => api.wearableReactionCorrelation() });
  const { elimination, startElimination, stopElimination, eliminationDay } = useInsightsStore();
  const top = candidates.data?.[0];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.heading}>Top allergen candidates</Text>
      {candidates.data?.length === 0 && (
        <Text style={styles.empty}>Log meals and symptoms to surface likely triggers.</Text>
      )}
      {candidates.data?.map((c) => (
        <Card key={c.ingredient_name} style={styles.candidate}>
          <View style={styles.candidateHead}>
            <Text style={styles.ingredient}>{c.ingredient_name}</Text>
            <Text style={styles.pct}>{c.label}</Text>
          </View>
          <ConfidenceBar score={c.confidence_score} />
          <Text style={styles.exposure}>
            {c.symptom_exposure_count} of {c.total_exposure_count} exposures linked to symptoms
          </Text>
        </Card>
      ))}

      {top && top.confidence_score > 0.7 && (
        <Card style={styles.elimCard}>
          <Text style={styles.heading}>Elimination protocol</Text>
          {elimination ? (
            <>
              <Text style={styles.elimText}>
                Day {eliminationDay()} of avoiding {elimination.ingredient}.
              </Text>
              <Button title="Stop test" variant="ghost" onPress={stopElimination} />
            </>
          ) : (
            <>
              <Text style={styles.elimText}>Try eliminating {top.ingredient_name} for 14 days.</Text>
              <Button
                title="Start 14-day test"
                onPress={() => {
                  startElimination(top.ingredient_name);
                  void scheduleEliminationReminder(top.ingredient_name, 1);
                }}
              />
            </>
          )}
        </Card>
      )}

      <Text style={styles.heading}>Wearable correlation</Text>
      <Card>
        <WearableCorrelation data={correlation.data ?? []} />
      </Card>

      <Text style={styles.heading}>Recent insights</Text>
      {insights.data?.length === 0 && <Text style={styles.empty}>No insights yet.</Text>}
      {insights.data?.map((i) => (
        <InsightCard key={i.id} insight={i} />
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, paddingBottom: 40 },
  heading: { color: Colors.text.primary, fontSize: 18, fontWeight: "800", marginVertical: 10 },
  empty: { color: Colors.text.secondary, paddingVertical: 8 },
  candidate: { marginBottom: 10 },
  candidateHead: { flexDirection: "row", justifyContent: "space-between", marginBottom: 8 },
  ingredient: { color: Colors.text.primary, fontSize: 16, fontWeight: "700", textTransform: "capitalize" },
  pct: { color: Colors.accent.coral, fontWeight: "700" },
  exposure: { color: Colors.text.secondary, fontSize: 12, marginTop: 6 },
  elimCard: { marginVertical: 10, gap: 8 },
  elimText: { color: Colors.text.primary, fontSize: 15 },
});
