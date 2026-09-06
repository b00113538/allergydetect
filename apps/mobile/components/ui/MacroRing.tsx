import { useEffect } from "react";
import { StyleSheet, Text, View } from "react-native";
import Animated, {
  useAnimatedProps,
  useSharedValue,
  withSpring,
} from "react-native-reanimated";
import Svg, { Circle } from "react-native-svg";

import { Colors } from "@/constants/colors";

const AnimatedCircle = Animated.createAnimatedComponent(Circle);

interface Props {
  label: string;
  value: number;
  target: number;
  unit?: string;
  color?: string;
  size?: number;
}

export function MacroRing({ label, value, target, unit = "g", color = Colors.accent.teal, size = 92 }: Props) {
  const stroke = 9;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const pct = target > 0 ? Math.min(value / target, 1) : 0;
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withSpring(pct, { damping: 14, stiffness: 90 });
  }, [pct, progress]);

  const animatedProps = useAnimatedProps(() => ({
    strokeDashoffset: circumference * (1 - progress.value),
  }));

  return (
    <View style={styles.wrap}>
      <Svg width={size} height={size}>
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={Colors.bg.elevated}
          strokeWidth={stroke}
          fill="none"
        />
        <AnimatedCircle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={color}
          strokeWidth={stroke}
          fill="none"
          strokeLinecap="round"
          strokeDasharray={circumference}
          animatedProps={animatedProps}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      </Svg>
      <View style={styles.center}>
        <Text style={styles.value}>{Math.round(value)}</Text>
        <Text style={styles.target}>/{Math.round(target)}{unit}</Text>
      </View>
      <Text style={styles.label}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: "center" },
  center: { position: "absolute", top: 26, alignItems: "center" },
  value: { color: Colors.text.primary, fontSize: 18, fontWeight: "800" },
  target: { color: Colors.text.secondary, fontSize: 10 },
  label: { color: Colors.text.secondary, fontSize: 12, marginTop: 6, fontWeight: "600" },
});
