import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

export interface HeatCell {
  date: string; // ISO yyyy-mm-dd
  value: number; // 0..1
}

interface Props {
  data: HeatCell[];
  weeks?: number;
  label?: string;
}

function color(v: number): string {
  if (v <= 0) return Colors.bg.elevated;
  if (v < 0.25) return `${Colors.accent.teal}40`;
  if (v < 0.5) return `${Colors.accent.teal}80`;
  if (v < 0.75) return `${Colors.accent.teal}BB`;
  return Colors.accent.teal;
}

export function CalendarHeatmap({ data, weeks = 12, label }: Props) {
  // Lay out as `weeks` columns × 7 rows (oldest → newest, top-down per col).
  const today = new Date();
  const map = new Map(data.map((d) => [d.date, d.value]));
  const totalDays = weeks * 7;
  const start = new Date(today);
  start.setDate(today.getDate() - totalDays + 1);

  const cells: { date: string; value: number }[] = [];
  for (let i = 0; i < totalDays; i++) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    cells.push({ date: key, value: map.get(key) ?? 0 });
  }

  // Pivot into columns of 7.
  const columns: { date: string; value: number }[][] = [];
  for (let c = 0; c < weeks; c++) {
    columns.push(cells.slice(c * 7, c * 7 + 7));
  }

  return (
    <View>
      {label && <Text style={styles.label}>{label}</Text>}
      <View style={styles.grid}>
        {columns.map((col, ci) => (
          <View key={ci} style={styles.col}>
            {col.map((cell) => (
              <View key={cell.date} style={[styles.cell, { backgroundColor: color(cell.value) }]} />
            ))}
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  label: { color: Colors.text.secondary, fontSize: 13, fontWeight: "600", marginBottom: 6 },
  grid: { flexDirection: "row", gap: 3 },
  col: { gap: 3 },
  cell: { width: 14, height: 14, borderRadius: 3 },
});
