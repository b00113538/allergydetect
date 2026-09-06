import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

interface Props {
  label: string;
  value: number;
  target: number;
  color?: string;
  unit?: string;
}

export function MacroBar({ label, value, target, color = Colors.accent.teal, unit = "g" }: Props) {
  const pct = target > 0 ? Math.min((value / target) * 100, 100) : 0;
  return (
    <View style={styles.row}>
      <View style={styles.labelRow}>
        <Text style={styles.label}>{label}</Text>
        <Text style={styles.value}>
          {Math.round(value)}/{Math.round(target)}
          {unit}
        </Text>
      </View>
      <View style={styles.track}>
        <View style={[styles.fill, { width: `${pct}%`, backgroundColor: color }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { marginVertical: 6 },
  labelRow: { flexDirection: "row", justifyContent: "space-between", marginBottom: 4 },
  label: { color: Colors.text.secondary, fontSize: 13, fontWeight: "600" },
  value: { color: Colors.text.primary, fontSize: 13, fontWeight: "700" },
  track: { height: 8, borderRadius: 4, backgroundColor: Colors.bg.elevated, overflow: "hidden" },
  fill: { height: "100%", borderRadius: 4 },
});
