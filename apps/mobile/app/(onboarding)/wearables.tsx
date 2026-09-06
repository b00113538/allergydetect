import { useRouter } from "expo-router";
import { Platform, ScrollView, StyleSheet, Text } from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { useGoogleHealth } from "@/hooks/useGoogleHealth";
import { useHealthKit } from "@/hooks/useHealthKit";

export default function OnboardingWearables() {
  const router = useRouter();
  const hk = useHealthKit();
  const gh = useGoogleHealth();
  const isIos = Platform.OS === "ios";

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.step}>Step 5 of 6</Text>
      <Text style={styles.title}>Connect a wearable</Text>
      <Card>
        <Text style={styles.body}>
          Linking heart-rate and HRV data lets AllergyDetect correlate physiological stress with your
          meals — sharpening allergen detection.
        </Text>
      </Card>
      <Button
        title={isIos ? "Connect Apple Health" : "Connect Google Health"}
        onPress={() => void (isIos ? hk.syncHealthData() : gh.syncHealthData())}
        style={{ marginTop: 16 }}
      />
      <Button title="Skip for now" variant="ghost" onPress={() => router.push("/(onboarding)/notifications")} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 20 },
  step: { color: Colors.accent.tealLight, fontWeight: "700" },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 16 },
  body: { color: Colors.text.secondary, lineHeight: 22 },
});
