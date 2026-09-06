import { useState } from "react";
import { Alert, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { ALLERGEN_MASTER_LIST, SEVERITY_LEVELS } from "@/constants/allergens";
import { api } from "@/lib/api";
import { useAuthStore } from "@/store/auth";
import { useUserStore } from "@/store/user";

export default function ProfileAllergies() {
  const allergies = useAuthStore((s) => s.allergies);
  const refreshMe = useAuthStore((s) => s.refreshMe);
  const { addAllergy, removeAllergy } = useUserStore();
  const [adding, setAdding] = useState("");
  const [severity, setSeverity] = useState<(typeof SEVERITY_LEVELS)[number]>("moderate");
  const [busy, setBusy] = useState(false);

  const toggleDoctor = async (id: string, value: boolean, name: string) => {
    // The backend's POST endpoint upserts on name, so we re-add with the new flag.
    await api.addAllergy({
      allergen_name: name,
      severity: allergies.find((a) => a.id === id)?.severity ?? "moderate",
      confirmed_by_doctor: value,
    });
    await refreshMe();
  };

  const submit = async () => {
    if (!adding.trim()) return;
    setBusy(true);
    try {
      const cat = ALLERGEN_MASTER_LIST.find((a) => a.name === adding.trim().toLowerCase())?.category;
      await addAllergy({
        allergen_name: adding.trim().toLowerCase(),
        severity,
        allergen_category: cat,
      });
      setAdding("");
    } catch {
      Alert.alert("Couldn't add allergy");
    } finally {
      setBusy(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card>
        <Text style={styles.title}>Add allergy</Text>
        <TextInput
          style={styles.input}
          placeholder="e.g. peanuts"
          placeholderTextColor={Colors.text.tertiary}
          value={adding}
          onChangeText={setAdding}
          autoCapitalize="none"
        />
        <View style={styles.row}>
          {SEVERITY_LEVELS.map((s) => (
            <Pressable key={s} onPress={() => setSeverity(s)} style={[styles.chip, severity === s && styles.chipActive]}>
              <Text style={[styles.chipText, severity === s && styles.chipTextActive]}>{s}</Text>
            </Pressable>
          ))}
        </View>
        <Button title="Add" onPress={submit} loading={busy} style={{ marginTop: 10 }} />
      </Card>

      <Text style={styles.section}>Your allergies ({allergies.length})</Text>
      {allergies.length === 0 && <Text style={styles.muted}>None recorded.</Text>}
      {allergies.map((a) => (
        <Card key={a.id} style={styles.allergyCard}>
          <View style={styles.headerRow}>
            <View style={{ flex: 1 }}>
              <Text style={styles.name}>{a.allergen_name}</Text>
              <Text style={styles.meta}>
                {a.severity}
                {a.allergen_category ? ` · ${a.allergen_category}` : ""}
              </Text>
            </View>
            <Pressable onPress={() => removeAllergy(a.id)}>
              <Text style={styles.delete}>Remove</Text>
            </Pressable>
          </View>
          <View style={styles.docRow}>
            <Text style={styles.docLabel}>Confirmed by doctor</Text>
            <Switch
              value={a.confirmed_by_doctor}
              onValueChange={(v) => toggleDoctor(a.id, v, a.allergen_name)}
              trackColor={{ true: Colors.accent.teal }}
            />
          </View>
        </Card>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 10 },
  title: { color: Colors.text.primary, fontSize: 18, fontWeight: "800", marginBottom: 8 },
  section: { color: Colors.text.primary, fontWeight: "800", marginTop: 8, marginBottom: 4 },
  muted: { color: Colors.text.secondary, paddingVertical: 8 },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, paddingHorizontal: 14, height: 48, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border },
  row: { flexDirection: "row", gap: 6, marginTop: 10, flexWrap: "wrap" },
  chip: { paddingVertical: 8, paddingHorizontal: 12, borderRadius: 999, backgroundColor: Colors.bg.elevated },
  chipActive: { backgroundColor: Colors.accent.teal },
  chipText: { color: Colors.text.secondary, fontWeight: "700", textTransform: "capitalize" },
  chipTextActive: { color: Colors.text.inverse },
  allergyCard: { gap: 8 },
  headerRow: { flexDirection: "row", alignItems: "center" },
  name: { color: Colors.text.primary, fontSize: 16, fontWeight: "700", textTransform: "capitalize" },
  meta: { color: Colors.text.tertiary, fontSize: 12, textTransform: "capitalize" },
  delete: { color: Colors.accent.coral, fontWeight: "700" },
  docRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingTop: 4 },
  docLabel: { color: Colors.text.secondary },
});
