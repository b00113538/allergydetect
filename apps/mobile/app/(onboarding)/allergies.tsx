import { useRouter } from "expo-router";
import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";
import { ALLERGEN_MASTER_LIST, SEVERITY_LEVELS } from "@/constants/allergens";
import { useUserStore } from "@/store/user";

export default function OnboardingAllergies() {
  const router = useRouter();
  const addAllergy = useUserStore((s) => s.addAllergy);
  const [selected, setSelected] = useState<Record<string, string>>({});
  const [search, setSearch] = useState("");
  const [saving, setSaving] = useState(false);

  const filtered = ALLERGEN_MASTER_LIST.filter((a) => a.name.includes(search.toLowerCase()));

  const toggle = (name: string) =>
    setSelected((s) => {
      const next = { ...s };
      if (next[name]) delete next[name];
      else next[name] = "moderate";
      return next;
    });

  const cycleSeverity = (name: string) =>
    setSelected((s) => {
      const idx = SEVERITY_LEVELS.indexOf((s[name] as (typeof SEVERITY_LEVELS)[number]) ?? "moderate");
      return { ...s, [name]: SEVERITY_LEVELS[(idx + 1) % SEVERITY_LEVELS.length] };
    });

  const next = async () => {
    setSaving(true);
    try {
      for (const [name, severity] of Object.entries(selected)) {
        const cat = ALLERGEN_MASTER_LIST.find((a) => a.name === name)?.category;
        await addAllergy({ allergen_name: name, severity, allergen_category: cat });
      }
      router.push("/(onboarding)/wearables");
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.step}>Step 4 of 6</Text>
      <Text style={styles.title}>Your allergies</Text>
      <TextInput
        style={styles.input}
        placeholder="Search allergens…"
        placeholderTextColor={Colors.text.tertiary}
        value={search}
        onChangeText={setSearch}
      />
      {filtered.map((a) => {
        const sel = selected[a.name];
        return (
          <View key={a.name} style={[styles.row, sel ? styles.rowActive : null]}>
            <Pressable style={{ flex: 1 }} onPress={() => toggle(a.name)}>
              <Text style={styles.name}>{a.name}</Text>
              <Text style={styles.cat}>{a.category}</Text>
            </Pressable>
            {sel && (
              <Pressable onPress={() => cycleSeverity(a.name)} style={styles.sevChip}>
                <Text style={styles.sevText}>{sel}</Text>
              </Pressable>
            )}
          </View>
        );
      })}
      <Button title="Continue" onPress={next} loading={saving} style={{ marginTop: 20 }} />
      <Button title="Skip" variant="ghost" onPress={() => router.push("/(onboarding)/wearables")} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 20 },
  step: { color: Colors.accent.tealLight, fontWeight: "700" },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 16 },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, paddingHorizontal: 14, height: 48, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border, marginBottom: 12 },
  row: { flexDirection: "row", alignItems: "center", padding: 14, borderRadius: 12, backgroundColor: Colors.bg.card, marginBottom: 8, borderWidth: 1, borderColor: Colors.border },
  rowActive: { borderColor: Colors.accent.teal },
  name: { color: Colors.text.primary, fontSize: 16, fontWeight: "700", textTransform: "capitalize" },
  cat: { color: Colors.text.tertiary, fontSize: 12 },
  sevChip: { backgroundColor: Colors.accent.amber, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 },
  sevText: { color: Colors.text.inverse, fontWeight: "700", textTransform: "capitalize" },
});
