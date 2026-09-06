import { useRouter } from "expo-router";
import { useState } from "react";
import { ScrollView, StyleSheet, Switch, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { registerForPush, scheduleDailyReminder } from "@/lib/notifications";
import { useUserStore } from "@/store/user";

export default function OnboardingNotifications() {
  const router = useRouter();
  const updateProfile = useUserStore((s) => s.updateProfile);
  const [checkin, setCheckin] = useState(true);
  const [daily, setDaily] = useState(true);
  const [weekly, setWeekly] = useState(true);
  const [finishing, setFinishing] = useState(false);

  const finish = async () => {
    setFinishing(true);
    try {
      await registerForPush();
      if (daily) await scheduleDailyReminder(19, 0);
      await updateProfile({ onboarding_complete: true });
      router.replace("/(tabs)");
    } finally {
      setFinishing(false);
    }
  };

  const Toggle = ({ label, value, onChange }: { label: string; value: boolean; onChange: (v: boolean) => void }) => (
    <View style={styles.toggleRow}>
      <Text style={styles.toggleLabel}>{label}</Text>
      <Switch value={value} onValueChange={onChange} trackColor={{ true: Colors.accent.teal }} />
    </View>
  );

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.step}>Step 6 of 6</Text>
      <Text style={styles.title}>Notifications</Text>
      <Card style={{ gap: 4 }}>
        <Toggle label="Post-meal symptom check-ins" value={checkin} onChange={setCheckin} />
        <Toggle label="Daily logging reminder" value={daily} onChange={setDaily} />
        <Toggle label="Weekly report" value={weekly} onChange={setWeekly} />
      </Card>
      <Button title="Start tracking 🎉" onPress={finish} loading={finishing} style={{ marginTop: 20 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 20 },
  step: { color: Colors.accent.tealLight, fontWeight: "700" },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 16 },
  toggleRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: 10 },
  toggleLabel: { color: Colors.text.primary, fontSize: 15, flex: 1 },
});
