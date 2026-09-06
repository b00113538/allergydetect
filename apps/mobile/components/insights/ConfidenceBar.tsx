import { useEffect } from "react";
import { StyleSheet, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from "react-native-reanimated";

import { Colors } from "@/constants/colors";

export function ConfidenceBar({ score }: { score: number }) {
  const pct = Math.min(Math.max(score, 0), 1);
  const w = useSharedValue(0);
  useEffect(() => {
    w.value = withTiming(pct, { duration: 700 });
  }, [pct, w]);

  const color = pct >= 0.7 ? Colors.accent.coral : pct >= 0.4 ? Colors.accent.amber : Colors.accent.teal;
  const style = useAnimatedStyle(() => ({ width: `${w.value * 100}%`, backgroundColor: color }));

  return (
    <View style={styles.track}>
      <Animated.View style={[styles.fill, style]} />
    </View>
  );
}

const styles = StyleSheet.create({
  track: { height: 10, borderRadius: 5, backgroundColor: Colors.bg.elevated, overflow: "hidden" },
  fill: { height: "100%", borderRadius: 5 },
});
