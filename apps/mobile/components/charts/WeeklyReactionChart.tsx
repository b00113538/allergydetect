import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

export interface DayDatum {
  date: string;
  count: number;
  avg_severity: number;
}

function sevColor(s: number): string {
  if (s >= 8) return Colors.accent.coral;
  if (s >= 5) return Colors.accent.amber;
  if (s > 0) return Colors.accent.teal;
  return Colors.bg.elevated;
}

export function WeeklyReactionChart({ data }: { data: DayDatum[] }) {
  const max = 10;
  return (
    <View style={styles.wrap}>
      {data.length === 0 && <Text style={styles.empty}>No reactions logged this week 🎉</Text>}
      <View style={styles.chart}>
        {data.map((d) => {
          const h = Math.max((d.avg_severity / max) * 120, 4);
          const label = new Date(d.date).toLocaleDateString([], { weekday: "short" });
          return (
            <View key={d.date} style={styles.col}>
              <View style={[styles.bar, { height: h, backgroundColor: sevColor(d.avg_severity) }]} />
              <Text style={styles.dayLabel}>{label}</Text>
            </View>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginTop: 8 },
  empty: { color: Colors.text.secondary, textAlign: "center", paddingVertical: 24 },
  chart: { flexDirection: "row", alignItems: "flex-end", justifyContent: "space-around", height: 150 },
  col: { alignItems: "center", flex: 1 },
  bar: { width: 22, borderRadius: 6 },
  dayLabel: { color: Colors.text.tertiary, fontSize: 10, marginTop: 6 },
});
