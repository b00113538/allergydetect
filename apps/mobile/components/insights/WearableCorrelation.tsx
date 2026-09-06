import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";

export interface CorrelationPoint {
  date: string;
  reaction: boolean;
  severity?: number;
  hrv_delta?: number | null;
  hr_delta?: number | null;
}

interface Props {
  data: CorrelationPoint[];
}

function severityColor(severity?: number): string {
  if (!severity) return Colors.accent.teal;
  if (severity >= 8) return Colors.accent.coral;
  if (severity >= 5) return Colors.accent.amber;
  return Colors.accent.teal;
}

export function WearableCorrelation({ data }: Props) {
  if (data.length === 0) {
    return <Text style={styles.empty}>Connect a wearable and log a few reactions to see the correlation.</Text>;
  }

  const summary = data.reduce(
    (acc, p) => {
      if (p.hrv_delta != null) {
        acc.hrv += p.hrv_delta;
        acc.hrvN++;
      }
      if (p.hr_delta != null) {
        acc.hr += p.hr_delta;
        acc.hrN++;
      }
      return acc;
    },
    { hrv: 0, hrvN: 0, hr: 0, hrN: 0 }
  );

  return (
    <View>
      <View style={styles.summary}>
        <View style={styles.summaryCell}>
          <Text style={styles.bigDelta}>{summary.hrvN ? (summary.hrv / summary.hrvN).toFixed(1) : "—"} ms</Text>
          <Text style={styles.smallLabel}>avg HRV change after reactions</Text>
        </View>
        <View style={styles.summaryCell}>
          <Text style={styles.bigDelta}>{summary.hrN ? (summary.hr / summary.hrN).toFixed(1) : "—"} bpm</Text>
          <Text style={styles.smallLabel}>avg HR change after reactions</Text>
        </View>
      </View>

      <Text style={styles.subtle}>
        Negative HRV deltas and positive HR deltas suggest physiological stress — useful triangulation
        alongside the symptom log.
      </Text>

      <View style={styles.list}>
        {data.slice(0, 10).map((p, i) => (
          <View key={i} style={styles.row}>
            <View style={[styles.dot, { backgroundColor: severityColor(p.severity) }]} />
            <Text style={styles.date}>{new Date(p.date).toLocaleDateString()}</Text>
            <Text style={styles.delta}>
              HRV {p.hrv_delta != null ? `${p.hrv_delta > 0 ? "+" : ""}${p.hrv_delta}` : "—"}
            </Text>
            <Text style={styles.delta}>
              HR {p.hr_delta != null ? `${p.hr_delta > 0 ? "+" : ""}${p.hr_delta}` : "—"}
            </Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  empty: { color: Colors.text.secondary, padding: 12 },
  summary: { flexDirection: "row", gap: 10 },
  summaryCell: { flex: 1, padding: 12, backgroundColor: Colors.bg.elevated, borderRadius: 12 },
  bigDelta: { color: Colors.accent.tealLight, fontSize: 22, fontWeight: "800" },
  smallLabel: { color: Colors.text.tertiary, fontSize: 11, marginTop: 4 },
  subtle: { color: Colors.text.tertiary, fontSize: 12, lineHeight: 18, marginTop: 10 },
  list: { marginTop: 10, gap: 6 },
  row: { flexDirection: "row", alignItems: "center", gap: 8 },
  dot: { width: 10, height: 10, borderRadius: 5 },
  date: { color: Colors.text.secondary, fontSize: 12, width: 90 },
  delta: { color: Colors.text.primary, fontSize: 12, width: 70 },
});
