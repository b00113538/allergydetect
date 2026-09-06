import { useEffect } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import Animated, {
  useAnimatedProps,
  useSharedValue,
  withTiming,
} from "react-native-reanimated";
import Svg, { Circle } from "react-native-svg";

import { Colors, scoreColor } from "@/constants/colors";

const AnimatedCircle = Animated.createAnimatedComponent(Circle);

interface Props {
  label: string;
  score: number;
  onPress?: () => void;
}

export function ScoreCard({ label, score, onPress }: Props) {
  const size = 84;
  const stroke = 7;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const color = scoreColor(score);
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withTiming(Math.min(score / 100, 1), { duration: 900 });
  }, [score, progress]);

  const animatedProps = useAnimatedProps(() => ({
    strokeDashoffset: circumference * (1 - progress.value),
  }));

  return (
    <Pressable onPress={onPress} style={styles.card}>
      <Svg width={size} height={size}>
        <Circle cx={size / 2} cy={size / 2} r={radius} stroke={Colors.bg.elevated} strokeWidth={stroke} fill="none" />
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
      <View style={styles.scoreCenter}>
        <Text style={[styles.score, { color }]}>{Math.round(score)}</Text>
      </View>
      <Text style={styles.label}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { flex: 1, alignItems: "center" },
  scoreCenter: { position: "absolute", top: 28 },
  score: { fontSize: 22, fontWeight: "800" },
  label: { color: Colors.text.secondary, fontSize: 11, marginTop: 6, textAlign: "center", fontWeight: "600" },
});
