import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

interface Props {
  label: string;
  color?: string;
  bg?: string;
}

export function Badge({ label, color = Colors.text.primary, bg = Colors.bg.elevated }: Props) {
  return (
    <View style={[styles.badge, { backgroundColor: bg }]}>
      <Text style={[styles.text, { color }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 999, alignSelf: "flex-start" },
  text: { fontSize: 12, fontWeight: "700" },
});
