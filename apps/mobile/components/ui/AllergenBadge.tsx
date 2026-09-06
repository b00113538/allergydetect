import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";
import type { AllergenStatus } from "@/lib/allergens";

interface Props {
  label: string;
  status: AllergenStatus;
}

export function AllergenBadge({ label, status }: Props) {
  const palette = Colors.allergen[status];
  return (
    <View style={[styles.badge, { backgroundColor: palette.bg, borderColor: palette.border }]}>
      <Text style={[styles.text, { color: palette.text }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: { paddingHorizontal: 10, paddingVertical: 5, borderRadius: 8, borderWidth: 1, alignSelf: "flex-start" },
  text: { fontSize: 12, fontWeight: "700", textTransform: "capitalize" },
});
