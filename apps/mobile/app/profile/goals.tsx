import { useEffect, useState } from "react";
import { Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { MacroBar } from "@/components/food/MacroBar";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";
import { useAuthStore } from "@/store/auth";
import { useUserStore } from "@/store/user";

const GOAL_TYPES = ["lose_fat", "maintain", "gain_muscle", "manage_allergies", "general_wellness"];

export default function ProfileGoals() {
  const { user, goals } = useAuthStore();
  const saveGoal = useUserStore((s) => s.saveGoal);
  const goal = goals[0];

  const [goalType, setGoalType] = useState(goal?.goal_type ?? "maintain");
  const [calories, setCalories] = useState(String(goal?.calories_target ?? 2000));
  const [protein, setProtein] = useState(String(goal?.protein_g ?? 150));
  const [carbs, setCarbs] = useState(String(goal?.carbs_g ?? 200));
  const [fat, setFat] = useState(String(goal?.fat_g ?? 70));
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!goal) return;
    setGoalType(goal.goal_type);
    setCalories(String(goal.calories_target ?? ""));
    setProtein(String(goal.protein_g ?? ""));
    setCarbs(String(goal.carbs_g ?? ""));
    setFat(String(goal.fat_g ?? ""));
  }, [goal]);

  const recalc = async () => {
    if (!user?.weight_kg || !user?.height_cm) {
      Alert.alert("Need profile", "Set your height and weight on the profile first.");
      return;
    }
    setBusy(true);
    try {
      const rec = await api.recommendMacros(goalType);
      setCalories(String(rec.calories));
      setProtein(String(rec.protein_g));
      setCarbs(String(rec.carbs_g));
      setFat(String(rec.fat_g));
    } finally {
      setBusy(false);
    }
  };

  const save = async () => {
    setBusy(true);
    try {
      await saveGoal({
        goal_type: goalType,
        calories_target: Number(calories) || undefined,
        protein_g: Number(protein) || undefined,
        carbs_g: Number(carbs) || undefined,
        fat_g: Number(fat) || undefined,
      });
      Alert.alert("Saved", "Macro targets updated.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card>
        <Text style={styles.title}>Goal</Text>
        <View style={styles.row}>
          {GOAL_TYPES.map((g) => (
            <Pressable key={g} onPress={() => setGoalType(g)} style={[styles.chip, goalType === g && styles.chipActive]}>
              <Text style={[styles.chipText, goalType === g && styles.chipTextActive]}>{g.replace("_", " ")}</Text>
            </Pressable>
          ))}
        </View>
        <Button title="Recalculate from TDEE" variant="secondary" onPress={recalc} loading={busy} style={{ marginTop: 12 }} />
      </Card>

      <Card>
        <Text style={styles.title}>Targets</Text>
        <Labelled label="Calories (kcal)" value={calories} onChangeText={setCalories} />
        <Labelled label="Protein (g)" value={protein} onChangeText={setProtein} />
        <Labelled label="Carbs (g)" value={carbs} onChangeText={setCarbs} />
        <Labelled label="Fat (g)" value={fat} onChangeText={setFat} />
      </Card>

      <Card>
        <Text style={styles.title}>Preview</Text>
        <MacroBar label="Protein" value={Number(protein) || 0} target={Number(protein) || 1} color={Colors.accent.teal} />
        <MacroBar label="Carbs" value={Number(carbs) || 0} target={Number(carbs) || 1} color={Colors.accent.blue} />
        <MacroBar label="Fat" value={Number(fat) || 0} target={Number(fat) || 1} color={Colors.accent.amber} />
      </Card>

      <Button title="Save goal" onPress={save} loading={busy} />
    </ScrollView>
  );
}

function Labelled({ label, value, onChangeText }: { label: string; value: string; onChangeText: (v: string) => void }) {
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        style={styles.input}
        value={value}
        onChangeText={onChangeText}
        keyboardType="numeric"
        placeholderTextColor={Colors.text.tertiary}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  title: { color: Colors.text.primary, fontSize: 18, fontWeight: "800", marginBottom: 8 },
  row: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  chip: { paddingVertical: 8, paddingHorizontal: 12, borderRadius: 999, backgroundColor: Colors.bg.elevated },
  chipActive: { backgroundColor: Colors.accent.teal },
  chipText: { color: Colors.text.secondary, fontWeight: "700", textTransform: "capitalize" },
  chipTextActive: { color: Colors.text.inverse },
  field: { marginTop: 8 },
  fieldLabel: { color: Colors.text.secondary, fontSize: 13, marginBottom: 4 },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, paddingHorizontal: 14, height: 46, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border },
});
