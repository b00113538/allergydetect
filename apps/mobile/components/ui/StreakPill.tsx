import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";
import type { StreakInfo } from "@/types";

const META: Record<string, { icon: string; label: string; color: string }> = {
  logging: { icon: "🔥", label: "Logging", color: Colors.accent.coral },
  reaction_free: { icon: "🛡️", label: "Reaction-free", color: Colors.accent.teal },
  protein_goal: { icon: "🎯", label: "Protein", color: Colors.accent.blue },
  hydration: { icon: "💧", label: "Hydration", color: Colors.accent.blueLight },
};

export function StreakPill({ streak }: { streak: StreakInfo }) {
  const meta = META[streak.type] ?? { icon: "⭐", label: streak.type, color: Colors.accent.purple };
  return (
    <View style={styles.pill}>
      <Text style={styles.icon}>{meta.icon}</Text>
      <View>
        <Text style={[styles.count, { color: meta.color }]}>{streak.current} days</Text>
        <Text style={styles.label}>{meta.label}</Text>
        <Text style={styles.record}>Best {streak.record}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    backgroundColor: Colors.bg.card,
    borderColor: Colors.border,
    borderWidth: 1,
    borderRadius: 14,
    padding: 12,
    marginRight: 10,
  },
  icon: { fontSize: 22 },
  count: { fontSize: 15, fontWeight: "800" },
  label: { color: Colors.text.secondary, fontSize: 11 },
  record: { color: Colors.text.tertiary, fontSize: 10 },
});
