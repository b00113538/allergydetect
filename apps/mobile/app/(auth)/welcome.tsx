import { useRouter } from "expo-router";
import { StyleSheet, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";

export default function Welcome() {
  const router = useRouter();
  return (
    <View style={styles.container}>
      <View style={styles.hero}>
        <Text style={styles.logo}>🛡️</Text>
        <Text style={styles.title}>AllergyDetect</Text>
        <Text style={styles.tagline}>
          AI-powered food intelligence and allergy safety in your pocket.
        </Text>
      </View>
      <View style={styles.actions}>
        <Button title="Get started" onPress={() => router.push("/(auth)/register")} />
        <Button title="I already have an account" variant="ghost" onPress={() => router.push("/(auth)/login")} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, justifyContent: "space-between", backgroundColor: Colors.bg.primary },
  hero: { flex: 1, alignItems: "center", justifyContent: "center", gap: 12 },
  logo: { fontSize: 72 },
  title: { color: Colors.text.primary, fontSize: 34, fontWeight: "800" },
  tagline: { color: Colors.text.secondary, fontSize: 16, textAlign: "center", paddingHorizontal: 20, lineHeight: 22 },
  actions: { gap: 12, paddingBottom: 24 },
});
