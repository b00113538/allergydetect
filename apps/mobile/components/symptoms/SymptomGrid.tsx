import { Pressable, StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";
import { SYMPTOM_OPTIONS } from "@/constants/symptoms";

interface Props {
  selected: string[];
  onToggle: (id: string) => void;
}

export function SymptomGrid({ selected, onToggle }: Props) {
  return (
    <View style={styles.grid}>
      {SYMPTOM_OPTIONS.map((s) => {
        const active = selected.includes(s.id);
        return (
          <Pressable
            key={s.id}
            onPress={() => onToggle(s.id)}
            style={[styles.cell, active && styles.cellActive, s.emergency && active && styles.emergency]}
          >
            <Text style={[styles.text, active && styles.textActive]}>{s.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  cell: {
    width: "47%",
    paddingVertical: 14,
    paddingHorizontal: 12,
    borderRadius: 12,
    backgroundColor: Colors.bg.card,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  cellActive: { backgroundColor: Colors.accent.coral, borderColor: Colors.accent.coral },
  emergency: { backgroundColor: Colors.allergen.confirmed.border },
  text: { color: Colors.text.secondary, fontWeight: "600", fontSize: 14 },
  textActive: { color: Colors.text.primary },
});
