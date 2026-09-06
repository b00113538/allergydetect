import { StyleSheet, Text, View } from "react-native";
import Svg, { Circle, Line, Polyline } from "react-native-svg";

import { Colors } from "@/constants/colors";

export interface TrendPoint {
  date: string;
  value: number;
}

interface Props {
  data: TrendPoint[];
  color?: string;
  height?: number;
  yMax?: number;
  label?: string;
}

export function MacroTrendLine({
  data,
  color = Colors.accent.teal,
  height = 140,
  yMax,
  label,
}: Props) {
  if (data.length < 2) {
    return (
      <View style={[styles.empty, { height }]}>
        <Text style={styles.emptyText}>Need at least 2 days of data.</Text>
      </View>
    );
  }
  const width = 300;
  const padX = 24;
  const padY = 16;
  const max = yMax ?? Math.max(...data.map((d) => d.value), 1);
  const min = Math.min(...data.map((d) => d.value), 0);
  const range = Math.max(max - min, 1);

  const points = data
    .map((d, i) => {
      const x = padX + (i / (data.length - 1)) * (width - padX * 2);
      const y = padY + (1 - (d.value - min) / range) * (height - padY * 2);
      return `${x},${y}`;
    })
    .join(" ");

  return (
    <View>
      {label && <Text style={styles.label}>{label}</Text>}
      <Svg width={width} height={height}>
        {[0.25, 0.5, 0.75].map((t) => (
          <Line
            key={t}
            x1={padX}
            x2={width - padX}
            y1={padY + (height - padY * 2) * t}
            y2={padY + (height - padY * 2) * t}
            stroke={Colors.border}
            strokeWidth={0.5}
          />
        ))}
        <Polyline points={points} stroke={color} strokeWidth={2.5} fill="none" strokeLinejoin="round" strokeLinecap="round" />
        {data.map((d, i) => {
          const x = padX + (i / (data.length - 1)) * (width - padX * 2);
          const y = padY + (1 - (d.value - min) / range) * (height - padY * 2);
          return <Circle key={d.date} cx={x} cy={y} r={3} fill={color} />;
        })}
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  empty: { alignItems: "center", justifyContent: "center" },
  emptyText: { color: Colors.text.tertiary, fontSize: 12 },
  label: { color: Colors.text.secondary, fontSize: 13, fontWeight: "600", marginBottom: 4 },
});
