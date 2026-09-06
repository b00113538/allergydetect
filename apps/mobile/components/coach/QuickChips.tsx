import { Pressable, ScrollView, StyleSheet, Text } from "react-native";

import { Colors } from "@/constants/colors";

const CHIPS = [
  "Top allergen risks",
  "How are my macros?",
  "Suggest a safe meal",
  "Explain my last reaction",
  "What did I eat most this week?",
];

export function QuickChips({ onPick }: { onPick: (text: string) => void }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
      {CHIPS.map((c) => (
        <Pressable key={c} onPress={() => onPick(c)} style={styles.chip}>
          <Text style={styles.text}>{c}</Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: { gap: 8, paddingHorizontal: 16, paddingVertical: 8 },
  chip: {
    backgroundColor: Colors.bg.elevated,
    borderRadius: 999,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  text: { color: Colors.accent.tealLight, fontSize: 13, fontWeight: "600" },
});
