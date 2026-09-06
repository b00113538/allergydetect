import { useState } from "react";
import { Alert, Linking, Modal, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { WeeklyReactionChart } from "@/components/charts/WeeklyReactionChart";
import { SeveritySlider } from "@/components/symptoms/SeveritySlider";
import { SymptomGrid } from "@/components/symptoms/SymptomGrid";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { useCreateSymptom, useWeeklySymptoms } from "@/hooks/useSymptoms";

export default function Symptoms() {
  const [selected, setSelected] = useState<string[]>([]);
  const [severity, setSeverity] = useState(3);
  const [notes, setNotes] = useState("");
  const [emergency, setEmergency] = useState(false);
  const create = useCreateSymptom();
  const weekly = useWeeklySymptoms();

  const toggle = (id: string) =>
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));

  const submit = async () => {
    if (selected.length === 0) {
      Alert.alert("Select symptoms", "Choose at least one symptom to log.");
      return;
    }
    const res = await create.mutateAsync({ symptoms: selected, severity, notes: notes || undefined });
    if (res.emergency_flag) {
      setEmergency(true);
    } else {
      Alert.alert("Logged", "Symptoms recorded. We'll analyse possible triggers.");
    }
    setSelected([]);
    setSeverity(3);
    setNotes("");
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card>
        <Text style={styles.title}>Log a reaction</Text>
        <SymptomGrid selected={selected} onToggle={toggle} />
        <View style={{ height: 16 }} />
        <SeveritySlider value={severity} onChange={setSeverity} />
        <TextInput
          style={styles.input}
          placeholder="Notes (optional)"
          placeholderTextColor={Colors.text.tertiary}
          value={notes}
          onChangeText={setNotes}
          multiline
        />
        <Button title="Log symptoms" onPress={submit} loading={create.isPending} style={{ marginTop: 12 }} />
      </Card>

      <Card style={{ marginTop: 16 }}>
        <Text style={styles.title}>This week</Text>
        <WeeklyReactionChart data={weekly.data?.daily ?? []} />
      </Card>

      <Modal visible={emergency} transparent animationType="fade">
        <View style={styles.modalBg}>
          <Card style={styles.modal}>
            <Text style={styles.modalTitle}>Seek Emergency Help</Text>
            <Text style={styles.modalBody}>
              Your symptoms may indicate a severe allergic reaction (anaphylaxis). Call emergency
              services immediately. If you have an epinephrine auto-injector (EpiPen), use it now.
            </Text>
            <Button title="Call Emergency Services" variant="danger" onPress={() => Linking.openURL("tel:911")} />
            <Button title="Dismiss" variant="ghost" onPress={() => setEmergency(false)} />
          </Card>
        </View>
      </Modal>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, paddingBottom: 40 },
  title: { color: Colors.text.primary, fontSize: 18, fontWeight: "800", marginBottom: 12 },
  input: {
    backgroundColor: Colors.bg.input,
    borderRadius: 12,
    padding: 14,
    color: Colors.text.primary,
    borderWidth: 1,
    borderColor: Colors.border,
    marginTop: 12,
    minHeight: 60,
  },
  modalBg: { flex: 1, backgroundColor: "#000000cc", alignItems: "center", justifyContent: "center", padding: 24 },
  modal: { width: "100%", gap: 12 },
  modalTitle: { color: Colors.allergen.confirmed.text, fontSize: 22, fontWeight: "800" },
  modalBody: { color: Colors.text.primary, fontSize: 15, lineHeight: 22 },
});
