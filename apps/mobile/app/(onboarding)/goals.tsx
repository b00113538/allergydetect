import { useRouter } from "expo-router";
import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";

const GOALS = [
  { id: "lose_fat", label: "Lose fat" },
  { id: "maintain", label: "Maintain" },
  { id: "gain_muscle", label: "Gain muscle" },
  { id: "manage_allergies", label: "Manage allergies" },
  { id: "general_wellness", label: "General wellness" },
];

export default function OnboardingGoals() {
  const router = useRouter();
  const [goal, setGoal] = useState("manage_allergies");

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.step}>Step 2 of 6</Text>
      <Text style={styles.title}>Your primary goal</Text>
      {GOALS.map((g) => (
        <Pressable key={g.id} onPress={() => setGoal(g.id)} style={[styles.chip, goal === g.id && styles.active]}>
          <Text style={[styles.text, goal === g.id && styles.textActive]}>{g.label}</Text>
        </Pressable>
      ))}
      <Button
        title="Continue"
        onPress={() => router.push({ pathname: "/(onboarding)/macros", params: { goal } })}
        style={{ marginTop: 20 }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 20 },
  step: { color: Colors.accent.tealLight, fontWeight: "700" },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 16 },
  chip: { padding: 18, borderRadius: 14, backgroundColor: Colors.bg.card, marginBottom: 10, borderWidth: 1, borderColor: Colors.border },
  active: { backgroundColor: Colors.accent.teal, borderColor: Colors.accent.teal },
  text: { color: Colors.text.primary, fontSize: 16, fontWeight: "700" },
  textActive: { color: Colors.text.inverse },
});
