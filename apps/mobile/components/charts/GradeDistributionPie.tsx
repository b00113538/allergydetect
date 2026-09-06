import { StyleSheet, Text, View } from "react-native";
import Svg, { Circle, G, Path } from "react-native-svg";

import { Colors, type GradeLetter } from "@/constants/colors";

const GRADES: GradeLetter[] = ["A", "B", "C", "D", "F"];

function arc(cx: number, cy: number, r: number, start: number, end: number): string {
  const sx = cx + r * Math.cos(start);
  const sy = cy + r * Math.sin(start);
  const ex = cx + r * Math.cos(end);
  const ey = cy + r * Math.sin(end);
  const large = end - start > Math.PI ? 1 : 0;
  return `M ${cx} ${cy} L ${sx} ${sy} A ${r} ${r} 0 ${large} 1 ${ex} ${ey} Z`;
}

export function GradeDistributionPie({ data, size = 180 }: { data: Record<string, number>; size?: number }) {
  const total = GRADES.reduce((n, g) => n + (data[g] ?? 0), 0);
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 4;

  if (total === 0) {
    return (
      <View style={[styles.empty, { width: size, height: size }]}>
        <Text style={styles.emptyText}>No meals graded yet</Text>
      </View>
    );
  }

  let cursor = -Math.PI / 2;
  const slices = GRADES.map((g) => {
    const count = data[g] ?? 0;
    if (count === 0) return null;
    const sweep = (count / total) * Math.PI * 2;
    const path = arc(cx, cy, r, cursor, cursor + sweep);
    cursor += sweep;
    return <Path key={g} d={path} fill={Colors.grade[g]} />;
  });

  return (
    <View style={styles.wrap}>
      <Svg width={size} height={size}>
        <G>{slices}</G>
        <Circle cx={cx} cy={cy} r={r * 0.55} fill={Colors.bg.card} />
      </Svg>
      <View style={styles.legend}>
        {GRADES.map((g) => {
          const pct = total > 0 ? Math.round(((data[g] ?? 0) / total) * 100) : 0;
          return (
            <View key={g} style={styles.legendItem}>
              <View style={[styles.swatch, { backgroundColor: Colors.grade[g] }]} />
              <Text style={styles.legendText}>
                {g}: {data[g] ?? 0} ({pct}%)
              </Text>
            </View>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flexDirection: "row", alignItems: "center", gap: 18 },
  empty: { alignItems: "center", justifyContent: "center", borderRadius: 999, borderWidth: 1, borderColor: Colors.border },
  emptyText: { color: Colors.text.tertiary, fontSize: 12, textAlign: "center", padding: 12 },
  legend: { gap: 6, flex: 1 },
  legendItem: { flexDirection: "row", alignItems: "center", gap: 8 },
  swatch: { width: 12, height: 12, borderRadius: 3 },
  legendText: { color: Colors.text.secondary, fontSize: 13 },
});
