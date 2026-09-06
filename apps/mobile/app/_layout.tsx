import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack, useRouter } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";

import { Colors } from "@/constants/colors";
import { setupNotificationHandler } from "@/lib/notifications";
import { useAuthStore } from "@/store/auth";

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, staleTime: 30_000 } },
});

export default function RootLayout() {
  const bootstrap = useAuthStore((s) => s.bootstrap);
  const router = useRouter();

  useEffect(() => {
    void bootstrap();
  }, [bootstrap]);

  useEffect(() => {
    const cleanup = setupNotificationHandler(router);
    return cleanup;
  }, [router]);

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: Colors.bg.primary }}>
      <QueryClientProvider client={queryClient}>
        <StatusBar style="light" />
        <Stack
          screenOptions={{
            headerStyle: { backgroundColor: Colors.bg.primary },
            headerTintColor: Colors.text.primary,
            contentStyle: { backgroundColor: Colors.bg.primary },
            headerShadowVisible: false,
          }}
        >
          <Stack.Screen name="index" options={{ headerShown: false }} />
          <Stack.Screen name="(auth)" options={{ headerShown: false }} />
          <Stack.Screen name="(onboarding)" options={{ headerShown: false }} />
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="travel-card" options={{ title: "Travel Allergy Card" }} />
        </Stack>
      </QueryClientProvider>
    </GestureHandlerRootView>
  );
}
