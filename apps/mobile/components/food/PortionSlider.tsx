import { Pressable, StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

interface Props {
  multiplier: number;
  onChange: (m: number) => void;
}

const STEPS = [0.5, 1, 1.5, 2, 3];

export function PortionSlider({ multiplier, onChange }: Props) {
  return (
    <View>
      <Text style={styles.label}>Adjust serving</Text>
      <View style={styles.row}>
        {STEPS.map((s) => {
          const active = Math.abs(s - multiplier) < 0.01;
          return (
            <Pressable
              key={s}
              onPress={() => onChange(s)}
              style={[styles.chip, active && styles.chipActive]}
            >
              <Text style={[styles.chipText, active && styles.chipTextActive]}>{s}×</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  label: { color: Colors.text.secondary, fontSize: 13, fontWeight: "600", marginBottom: 8 },
  row: { flexDirection: "row", gap: 8 },
  chip: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    backgroundColor: Colors.bg.elevated,
    alignItems: "center",
  },
  chipActive: { backgroundColor: Colors.accent.teal },
  chipText: { color: Colors.text.secondary, fontWeight: "700" },
  chipTextActive: { color: Colors.text.inverse },
});
