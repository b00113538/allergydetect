import { useQuery } from "@tanstack/react-query";
import { useLocalSearchParams, useRouter } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { SYMPTOM_OPTIONS } from "@/constants/symptoms";
import { api } from "@/lib/api";

function labelFor(id: string): string {
  return SYMPTOM_OPTIONS.find((s) => s.id === id)?.label ?? id;
}

function severityColor(s: number): string {
  if (s >= 8) return Colors.accent.coral;
  if (s >= 5) return Colors.accent.amber;
  return Colors.accent.teal;
}

export default function SymptomDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const list = useQuery({ queryKey: ["symptoms"], queryFn: () => api.listSymptoms({ limit: 100 }) });
  const symptom = list.data?.find((s) => s.id === id);

  if (list.isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={Colors.accent.teal} />
      </View>
    );
  }

  if (!symptom) {
    return (
      <View style={styles.center}>
        <Text style={styles.muted}>Symptom log not found.</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card>
        <Text style={styles.title}>{new Date(symptom.logged_at).toLocaleString()}</Text>
        <View style={styles.sevRow}>
          <View style={[styles.sevBadge, { backgroundColor: severityColor(symptom.severity) }]}>
            <Text style={styles.sevText}>{symptom.severity}/10</Text>
          </View>
          {symptom.anaphylaxis_suspected && (
            <Text style={styles.anaphyl}>⚠ Anaphylaxis suspected</Text>
          )}
        </View>
      </Card>

      <Card>
        <Text style={styles.section}>Symptoms</Text>
        <View style={styles.chips}>
          {symptom.symptoms.map((s) => (
            <View key={s} style={styles.chip}>
              <Text style={styles.chipText}>{labelFor(s)}</Text>
            </View>
          ))}
        </View>
      </Card>

      {symptom.notes && (
        <Card>
          <Text style={styles.section}>Notes</Text>
          <Text style={styles.body}>{symptom.notes}</Text>
        </Card>
      )}

      {symptom.linked_food_log_ids.length > 0 && (
        <Card>
          <Text style={styles.section}>Linked meals</Text>
          {symptom.linked_food_log_ids.map((mealId) => (
            <Pressable key={mealId} onPress={() => router.push(`/log/meal/${mealId}`)}>
              <Text style={styles.link}>View meal →</Text>
            </Pressable>
          ))}
        </Card>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 10 },
  center: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: Colors.bg.primary },
  muted: { color: Colors.text.secondary },
  title: { color: Colors.text.primary, fontSize: 18, fontWeight: "800" },
  sevRow: { flexDirection: "row", alignItems: "center", gap: 12, marginTop: 8 },
  sevBadge: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 10 },
  sevText: { color: Colors.text.inverse, fontWeight: "800" },
  anaphyl: { color: Colors.allergen.confirmed.text, fontWeight: "700" },
  section: { color: Colors.text.primary, fontWeight: "800", marginBottom: 8 },
  body: { color: Colors.text.secondary, lineHeight: 22 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 8, backgroundColor: Colors.bg.elevated },
  chipText: { color: Colors.text.primary, fontWeight: "600", fontSize: 13 },
  link: { color: Colors.accent.tealLight, fontWeight: "700", paddingVertical: 4 },
});
