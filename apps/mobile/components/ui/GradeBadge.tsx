import { Pressable, StyleSheet, Text } from "react-native";

import { Colors, type GradeLetter } from "@/constants/colors";

interface Props {
  grade: GradeLetter | null | undefined;
  size?: number;
  onPress?: () => void;
}

export function GradeBadge({ grade, size = 40, onPress }: Props) {
  const g = (grade ?? "C") as GradeLetter;
  const color = Colors.grade[g];
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.badge,
        { width: size, height: size, borderRadius: size / 4, backgroundColor: `${color}22`, borderColor: color },
      ]}
    >
      <Text style={[styles.text, { color, fontSize: size * 0.45 }]}>{g}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  badge: { alignItems: "center", justifyContent: "center", borderWidth: 2 },
  text: { fontWeight: "800" },
});
