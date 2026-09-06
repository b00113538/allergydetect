import { StyleSheet, Text, View } from "react-native";
import Svg, { Circle, Line, Polygon, Text as SvgText } from "react-native-svg";

import { Colors } from "@/constants/colors";

interface Props {
  breakdown: Record<string, number>;
  size?: number;
}

const ORDER = [
  { key: "macro_alignment", label: "Macros" },
  { key: "ingredient_quality", label: "Quality" },
  { key: "micronutrient_density", label: "Micro" },
  { key: "allergen_safety", label: "Allergen" },
  { key: "meal_timing", label: "Timing" },
];

export function FoodGradeRadar({ breakdown, size = 220 }: Props) {
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 28;

  // Weighted-component scores are already 0..max_weighting (0..30 for macros, etc.).
  // Normalize each to 0..1 against its weight.
  const weights: Record<string, number> = {
    macro_alignment: 30,
    ingredient_quality: 25,
    micronutrient_density: 20,
    allergen_safety: 15,
    meal_timing: 10,
  };

  const angle = (i: number) => -Math.PI / 2 + (i / ORDER.length) * Math.PI * 2;

  const points = ORDER.map((o, i) => {
    const norm = Math.min(((breakdown[o.key] ?? 0) / weights[o.key]) || 0, 1);
    const a = angle(i);
    return [cx + Math.cos(a) * r * norm, cy + Math.sin(a) * r * norm] as const;
  });
  const pointsStr = points.map(([x, y]) => `${x},${y}`).join(" ");

  return (
    <View style={styles.wrap}>
      <Svg width={size} height={size}>
        {[0.25, 0.5, 0.75, 1].map((t) => (
          <Circle key={t} cx={cx} cy={cy} r={r * t} stroke={Colors.border} strokeWidth={0.5} fill="none" />
        ))}
        {ORDER.map((_, i) => {
          const a = angle(i);
          return <Line key={i} x1={cx} y1={cy} x2={cx + Math.cos(a) * r} y2={cy + Math.sin(a) * r} stroke={Colors.border} strokeWidth={0.5} />;
        })}
        <Polygon points={pointsStr} fill={`${Colors.accent.teal}55`} stroke={Colors.accent.teal} strokeWidth={2} />
        {ORDER.map((o, i) => {
          const a = angle(i);
          return (
            <SvgText
              key={o.key}
              x={cx + Math.cos(a) * (r + 14)}
              y={cy + Math.sin(a) * (r + 14) + 4}
              fill={Colors.text.secondary}
              fontSize={11}
              textAnchor="middle"
            >
              {o.label}
            </SvgText>
          );
        })}
      </Svg>
      <Text style={styles.caption}>Grade breakdown</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: "center" },
  caption: { color: Colors.text.tertiary, fontSize: 11, marginTop: 4 },
});
