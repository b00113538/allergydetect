import { useRouter } from "expo-router";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { useAuthStore } from "@/store/auth";

export default function Profile() {
  const router = useRouter();
  const { user, allergies, goals, logout } = useAuthStore();
  const goal = goals[0];

  const links: { label: string; href: string }[] = [
    { label: "Manage allergies", href: "/profile/allergies" },
    { label: "Goals & macros", href: "/profile/goals" },
    { label: "Wearables", href: "/profile/wearables" },
    { label: "Travel allergy card", href: "/travel-card" },
    { label: "Weekly report", href: "/reports/weekly" },
    { label: "Monthly report", href: "/reports/monthly" },
    { label: "Year in review", href: "/reports/yearly" },
    { label: "Community", href: "/community" },
  ];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Card style={styles.header}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{user?.name?.[0]?.toUpperCase() ?? "?"}</Text>
        </View>
        <Text style={styles.name}>{user?.name}</Text>
        <Text style={styles.email}>{user?.email}</Text>
      </Card>

      <Card>
        <Text style={styles.sectionTitle}>Goal</Text>
        <Text style={styles.detail}>
          {goal?.goal_type ?? "Not set"} · {goal?.calories_target ?? "—"} kcal
        </Text>
      </Card>

      <Card>
        <Text style={styles.sectionTitle}>Allergies ({allergies.length})</Text>
        {allergies.map((a) => (
          <Text key={a.id} style={styles.detail}>
            {a.allergen_name} — {a.severity}
            {a.confirmed_by_doctor ? " ✓" : ""}
          </Text>
        ))}
        {allergies.length === 0 && <Text style={styles.detail}>None recorded.</Text>}
      </Card>

      {links.map((l) => (
        <Pressable key={l.href} onPress={() => router.push(l.href as never)}>
          <Card style={styles.link}>
            <Text style={styles.linkText}>{l.label}</Text>
            <Text style={styles.chevron}>›</Text>
          </Card>
        </Pressable>
      ))}

      <Button title="Sign out" variant="danger" onPress={() => logout()} style={{ marginTop: 16 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  header: { alignItems: "center", gap: 6 },
  avatar: { width: 72, height: 72, borderRadius: 36, backgroundColor: Colors.accent.teal, alignItems: "center", justifyContent: "center" },
  avatarText: { color: Colors.text.inverse, fontSize: 28, fontWeight: "800" },
  name: { color: Colors.text.primary, fontSize: 20, fontWeight: "800" },
  email: { color: Colors.text.secondary },
  sectionTitle: { color: Colors.text.primary, fontWeight: "800", marginBottom: 6 },
  detail: { color: Colors.text.secondary, marginVertical: 2, textTransform: "capitalize" },
  link: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  linkText: { color: Colors.text.primary, fontWeight: "600" },
  chevron: { color: Colors.text.tertiary, fontSize: 22 },
});
