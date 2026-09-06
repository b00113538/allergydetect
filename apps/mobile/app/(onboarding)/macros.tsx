import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useState } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

import { MacroBar } from "@/components/food/MacroBar";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";
import { useUserStore } from "@/store/user";

interface Rec {
  tdee_kcal: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
}

export default function OnboardingMacros() {
  const router = useRouter();
  const { goal } = useLocalSearchParams<{ goal: string }>();
  const goalType = goal ?? "manage_allergies";
  const saveGoal = useUserStore((s) => s.saveGoal);
  const [rec, setRec] = useState<Rec | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        setRec(await api.recommendMacros(goalType));
      } catch {
        setRec(null);
      }
    })();
  }, [goalType]);

  const next = async () => {
    if (!rec) return;
    setSaving(true);
    try {
      await saveGoal({
        goal_type: goalType,
        calories_target: rec.calories,
        protein_g: rec.protein_g,
        carbs_g: rec.carbs_g,
        fat_g: rec.fat_g,
        fiber_g: rec.fiber_g,
      });
      router.push("/(onboarding)/allergies");
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.step}>Step 3 of 6</Text>
      <Text style={styles.title}>Recommended macros</Text>
      {rec ? (
        <Card>
          <Text style={styles.tdee}>TDEE ≈ {rec.tdee_kcal} kcal/day</Text>
          <Text style={styles.target}>Daily target: {rec.calories} kcal</Text>
          <View style={{ height: 12 }} />
          <MacroBar label="Protein" value={rec.protein_g} target={rec.protein_g} color={Colors.accent.teal} />
          <MacroBar label="Carbs" value={rec.carbs_g} target={rec.carbs_g} color={Colors.accent.blue} />
          <MacroBar label="Fat" value={rec.fat_g} target={rec.fat_g} color={Colors.accent.amber} />
        </Card>
      ) : (
        <Text style={styles.note}>Complete your profile to compute macros.</Text>
      )}
      <Button title="Use these targets" onPress={next} loading={saving} style={{ marginTop: 20 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 20 },
  step: { color: Colors.accent.tealLight, fontWeight: "700" },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 16 },
  tdee: { color: Colors.text.primary, fontSize: 18, fontWeight: "800" },
  target: { color: Colors.accent.tealLight, fontSize: 15, marginTop: 4 },
  note: { color: Colors.text.secondary },
});
