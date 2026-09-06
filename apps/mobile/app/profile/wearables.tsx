import { useState } from "react";
import { Alert, Platform, ScrollView, StyleSheet, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { useGoogleHealth } from "@/hooks/useGoogleHealth";
import { useHealthKit } from "@/hooks/useHealthKit";
import { useWearableSummary } from "@/hooks/useWearables";

export default function ProfileWearables() {
  const hk = useHealthKit();
  const gh = useGoogleHealth();
  const summary = useWearableSummary(7);
  const [lastSync, setLastSync] = useState<string | null>(null);
  const isIos = Platform.OS === "ios";

  const sync = async () => {
    try {
      const n = isIos ? await hk.syncHealthData() : await gh.syncHealthData();
      setLastSync(new Date().toLocaleString());
      summary.refetch();
      Alert.alert("Synced", `${n} readings imported.`);
    } catch {
      Alert.alert("Sync failed");
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card>
        <Text style={styles.title}>{isIos ? "Apple Health" : "Google Health Connect"}</Text>
        <Text style={styles.body}>
          {isIos ? hk.available : gh.available
            ? "Available on this device. Sync to pull heart-rate, HRV, sleep, and steps from the last 7 days."
            : "Native module requires a custom dev build on a real device. Use Expo Go for everything else."}
        </Text>
        <Button title={hk.syncing || gh.syncing ? "Syncing…" : "Sync now"} onPress={sync} loading={hk.syncing || gh.syncing} style={{ marginTop: 12 }} />
        {lastSync && <Text style={styles.meta}>Last sync: {lastSync}</Text>}
      </Card>

      <Card>
        <Text style={styles.title}>7-day averages</Text>
        <Row label="HRV" value={summary.data?.avg_hrv} unit="ms" />
        <Row label="Resting HR" value={summary.data?.avg_resting_hr} unit="bpm" />
        <Row label="Sleep score" value={summary.data?.avg_sleep_score} unit="" />
        <Row label="Steps" value={summary.data?.avg_steps} unit="" />
        <Row label="SpO₂" value={summary.data?.avg_spo2} unit="%" />
      </Card>
    </ScrollView>
  );
}

function Row({ label, value, unit }: { label: string; value?: number | null; unit: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value != null ? `${value}${unit ? " " + unit : ""}` : "—"}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  title: { color: Colors.text.primary, fontSize: 18, fontWeight: "800", marginBottom: 6 },
  body: { color: Colors.text.secondary, lineHeight: 20 },
  meta: { color: Colors.text.tertiary, marginTop: 8, fontSize: 12 },
  row: { flexDirection: "row", justifyContent: "space-between", paddingVertical: 6 },
  rowLabel: { color: Colors.text.secondary },
  rowValue: { color: Colors.text.primary, fontWeight: "700" },
});
