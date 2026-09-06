import { Redirect } from "expo-router";
import { ActivityIndicator, View } from "react-native";

import { Colors } from "@/constants/colors";
import { useAuthStore } from "@/store/auth";

export default function Index() {
  const { status, user } = useAuthStore();

  if (status === "loading") {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: Colors.bg.primary }}>
        <ActivityIndicator color={Colors.accent.teal} size="large" />
      </View>
    );
  }

  if (status === "unauthenticated" || !user) {
    return <Redirect href="/(auth)/welcome" />;
  }

  if (!user.onboarding_complete) {
    return <Redirect href="/(onboarding)/profile" />;
  }

  return <Redirect href="/(tabs)" />;
}
