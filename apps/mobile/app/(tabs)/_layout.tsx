import { Tabs, useRouter } from "expo-router";
import { Pressable, Text } from "react-native";

import { Colors } from "@/constants/colors";

function icon(emoji: string) {
  return ({ color }: { color: string }) => <Text style={{ fontSize: 22, color }}>{emoji}</Text>;
}

export default function TabsLayout() {
  const router = useRouter();
  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: Colors.bg.primary },
        headerTintColor: Colors.text.primary,
        headerShadowVisible: false,
        tabBarStyle: { backgroundColor: Colors.bg.card, borderTopColor: Colors.border },
        tabBarActiveTintColor: Colors.accent.teal,
        tabBarInactiveTintColor: Colors.text.tertiary,
        headerRight: () => (
          <Pressable onPress={() => router.push("/profile")} hitSlop={10} style={{ paddingHorizontal: 14 }}>
            <Text style={{ fontSize: 22 }}>👤</Text>
          </Pressable>
        ),
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Home", tabBarIcon: icon("🏠") }} />
      <Tabs.Screen name="scan" options={{ title: "Scan", tabBarIcon: icon("📷") }} />
      <Tabs.Screen name="symptoms" options={{ title: "Symptoms", tabBarIcon: icon("🩺") }} />
      <Tabs.Screen name="insights" options={{ title: "Insights", tabBarIcon: icon("💡") }} />
      <Tabs.Screen name="coach" options={{ title: "Coach", tabBarIcon: icon("🤖") }} />
    </Tabs>
  );
}
