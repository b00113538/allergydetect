import { useLocalSearchParams, useRouter } from "expo-router";
import { ScrollView, StyleSheet, Text, View } from "react-native";

import { AllergenBadge } from "@/components/ui/AllergenBadge";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { GradeBadge } from "@/components/ui/GradeBadge";
import { Colors } from "@/constants/colors";
import { useDeleteFoodLog, useFoodLog } from "@/hooks/useFoodLog";
import { matchStatus } from "@/lib/allergens";
import { useAuthStore } from "@/store/auth";

export default function MealDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const log = useFoodLog(id ?? "");
  const del = useDeleteFoodLog();
  const allergies = useAuthStore((s) => s.allergies);

  if (!log.data) {
    return (
      <View style={styles.center}>
        <Text style={styles.muted}>Loading meal…</Text>
      </View>
    );
  }

  const m = log.data;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <GradeBadge grade={m.meal_grade} size={48} />
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>{m.meal_type}</Text>
          <Text style={styles.meta}>{Math.round(m.total_calories)} kcal · {m.source}</Text>
        </View>
      </View>

      {m.items.map((item) => (
        <Card key={item.id ?? item.ingredient_name} style={styles.item}>
          <Text style={styles.ingredient}>{item.ingredient_name}</Text>
          <Text style={styles.macros}>
            {Math.round(item.quantity_g)}g · {Math.round(item.calories ?? 0)} kcal · P{Math.round(item.protein_g ?? 0)} C{Math.round(item.carbs_g ?? 0)} F{Math.round(item.fat_g ?? 0)}
          </Text>
          {item.allergen_flags.length > 0 && (
            <View style={styles.flags}>
              {item.allergen_flags.map((f, i) => (
                <AllergenBadge key={i} label={f} status={matchStatus([f], allergies)} />
              ))}
            </View>
          )}
        </Card>
      ))}

      <Button
        title="Delete meal"
        variant="danger"
        onPress={async () => {
          await del.mutateAsync(m.id);
          router.back();
        }}
        style={{ marginTop: 16 }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 10 },
  center: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: Colors.bg.primary },
  muted: { color: Colors.text.secondary },
  header: { flexDirection: "row", alignItems: "center", gap: 14, marginBottom: 8 },
  title: { color: Colors.text.primary, fontSize: 22, fontWeight: "800", textTransform: "capitalize" },
  meta: { color: Colors.text.secondary, marginTop: 2, textTransform: "capitalize" },
  item: { gap: 6 },
  ingredient: { color: Colors.text.primary, fontSize: 16, fontWeight: "700", textTransform: "capitalize" },
  macros: { color: Colors.text.secondary, fontSize: 13 },
  flags: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginTop: 4 },
});
