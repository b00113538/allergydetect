import { StyleSheet, Text, View } from "react-native";

import { Card } from "@/components/ui/Card";
import { GradeBadge } from "@/components/ui/GradeBadge";
import { Colors } from "@/constants/colors";
import type { FoodLog } from "@/types";

function timeLabel(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export function MealCard({ log, onPress }: { log: FoodLog; onPress?: () => void }) {
  const allergenCount = log.items.reduce((n, i) => n + (i.allergen_flags?.length ?? 0), 0);
  const title = log.items[0]?.ingredient_name ?? log.meal_type;
  return (
    <Card onPress={onPress} style={styles.card}>
      <View style={styles.header}>
        <GradeBadge grade={log.meal_grade} size={36} />
        {allergenCount > 0 && (
          <View style={styles.warn}>
            <Text style={styles.warnText}>⚠ {allergenCount}</Text>
          </View>
        )}
      </View>
      <Text style={styles.title} numberOfLines={1}>
        {title}
      </Text>
      <Text style={styles.meta}>
        {log.meal_type} · {timeLabel(log.logged_at)}
      </Text>
      <Text style={styles.cal}>{Math.round(log.total_calories)} kcal</Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { width: 160, marginRight: 12 },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  warn: { backgroundColor: Colors.allergen.confirmed.bg, borderRadius: 8, paddingHorizontal: 8, paddingVertical: 3 },
  warnText: { color: Colors.allergen.confirmed.text, fontWeight: "700", fontSize: 12 },
  title: { color: Colors.text.primary, fontWeight: "700", fontSize: 15, marginTop: 10, textTransform: "capitalize" },
  meta: { color: Colors.text.secondary, fontSize: 12, marginTop: 2, textTransform: "capitalize" },
  cal: { color: Colors.accent.tealLight, fontSize: 13, fontWeight: "700", marginTop: 8 },
});
