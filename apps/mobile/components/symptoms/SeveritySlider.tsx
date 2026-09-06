import * as Haptics from "expo-haptics";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

interface Props {
  value: number;
  onChange: (v: number) => void;
}

function levelColor(v: number): string {
  if (v >= 8) return Colors.accent.coral;
  if (v >= 5) return Colors.accent.amber;
  return Colors.accent.teal;
}

export function SeveritySlider({ value, onChange }: Props) {
  return (
    <View>
      <View style={styles.header}>
        <Text style={styles.label}>Severity</Text>
        <Text style={[styles.value, { color: levelColor(value) }]}>{value}/10</Text>
      </View>
      <View style={styles.row}>
        {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => {
          const active = n <= value;
          return (
            <Pressable
              key={n}
              onPress={() => {
                void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                onChange(n);
              }}
              style={[styles.segment, { backgroundColor: active ? levelColor(value) : Colors.bg.elevated }]}
            />
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: "row", justifyContent: "space-between", marginBottom: 8 },
  label: { color: Colors.text.secondary, fontSize: 14, fontWeight: "600" },
  value: { fontSize: 16, fontWeight: "800" },
  row: { flexDirection: "row", gap: 4 },
  segment: { flex: 1, height: 28, borderRadius: 6 },
});
