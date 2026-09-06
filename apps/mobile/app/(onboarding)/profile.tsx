import { useRouter } from "expo-router";
import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";
import { useUserStore } from "@/store/user";
import { useAuthStore } from "@/store/auth";

const SEXES = ["female", "male"];
const ACTIVITY = ["sedentary", "light", "moderate", "active", "very_active"];

export default function OnboardingProfile() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const updateProfile = useUserStore((s) => s.updateProfile);
  const [name, setName] = useState(user?.name ?? "");
  const [sex, setSex] = useState("female");
  const [height, setHeight] = useState("170");
  const [weight, setWeight] = useState("70");
  const [activity, setActivity] = useState("moderate");
  const [dob, setDob] = useState("1995-01-01");

  const next = async () => {
    await updateProfile({
      name,
      biological_sex: sex,
      height_cm: Number(height),
      weight_kg: Number(weight),
      activity_level: activity,
      dob,
    });
    router.push("/(onboarding)/goals");
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.step}>Step 1 of 6</Text>
      <Text style={styles.title}>About you</Text>

      <Text style={styles.label}>Name</Text>
      <TextInput style={styles.input} value={name} onChangeText={setName} placeholderTextColor={Colors.text.tertiary} />

      <Text style={styles.label}>Date of birth (YYYY-MM-DD)</Text>
      <TextInput style={styles.input} value={dob} onChangeText={setDob} placeholderTextColor={Colors.text.tertiary} />

      <Text style={styles.label}>Biological sex</Text>
      <View style={styles.row}>
        {SEXES.map((s) => (
          <Pressable key={s} onPress={() => setSex(s)} style={[styles.seg, sex === s && styles.segActive]}>
            <Text style={[styles.segText, sex === s && styles.segTextActive]}>{s}</Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.rowGap}>
        <View style={{ flex: 1 }}>
          <Text style={styles.label}>Height (cm)</Text>
          <TextInput style={styles.input} value={height} onChangeText={setHeight} keyboardType="numeric" />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={styles.label}>Weight (kg)</Text>
          <TextInput style={styles.input} value={weight} onChangeText={setWeight} keyboardType="numeric" />
        </View>
      </View>

      <Text style={styles.label}>Activity level</Text>
      <View style={styles.wrap}>
        {ACTIVITY.map((a) => (
          <Pressable key={a} onPress={() => setActivity(a)} style={[styles.chip, activity === a && styles.segActive]}>
            <Text style={[styles.segText, activity === a && styles.segTextActive]}>{a.replace("_", " ")}</Text>
          </Pressable>
        ))}
      </View>

      <Button title="Continue" onPress={next} style={{ marginTop: 20 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 20, paddingBottom: 40 },
  step: { color: Colors.accent.tealLight, fontWeight: "700" },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 16 },
  label: { color: Colors.text.secondary, fontWeight: "600", marginTop: 14, marginBottom: 6 },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, paddingHorizontal: 14, height: 50, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border },
  row: { flexDirection: "row", gap: 8 },
  rowGap: { flexDirection: "row", gap: 12 },
  seg: { flex: 1, paddingVertical: 12, borderRadius: 10, backgroundColor: Colors.bg.card, alignItems: "center" },
  segActive: { backgroundColor: Colors.accent.teal },
  segText: { color: Colors.text.secondary, fontWeight: "700", textTransform: "capitalize" },
  segTextActive: { color: Colors.text.inverse },
  wrap: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingVertical: 10, paddingHorizontal: 14, borderRadius: 10, backgroundColor: Colors.bg.card },
});
