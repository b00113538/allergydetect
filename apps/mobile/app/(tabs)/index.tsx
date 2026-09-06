import { useRouter } from "expo-router";
import { useCallback } from "react";
import { FlatList, RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";

import { MealCard } from "@/components/food/MealCard";
import { Card } from "@/components/ui/Card";
import { MacroRing } from "@/components/ui/MacroRing";
import { ScoreCard } from "@/components/ui/ScoreCard";
import { StreakPill } from "@/components/ui/StreakPill";
import { Colors } from "@/constants/colors";
import { useDailyInsight } from "@/hooks/useInsights";
import { useToday } from "@/hooks/useFoodLog";
import { useStreaks } from "@/hooks/useStreaks";
import { useAuthStore } from "@/store/auth";

export default function Home() {
  const router = useRouter();
  const { user, goals } = useAuthStore();
  const today = useToday();
  const insight = useDailyInsight();
  const goal = goals[0];

  const totals = today.data?.totals;
  const scores = today.data?.daily_scores;
  const logs = today.data?.logs ?? [];
  const streaks = useStreaks(logs.length, 0);

  const onRefresh = useCallback(() => {
    void today.refetch();
    void insight.refetch();
  }, [today, insight]);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={today.isFetching} onRefresh={onRefresh} tintColor={Colors.accent.teal} />}
    >
      <Text style={styles.greeting}>Hi {user?.name?.split(" ")[0] ?? "there"} 👋</Text>

      <Card style={styles.section}>
        <Text style={styles.sectionTitle}>Today's scores</Text>
        <View style={styles.scoreRow}>
          <ScoreCard label="Meal Quality" score={scores?.meal_quality ?? 0} />
          <ScoreCard label="Eating Rhythm" score={scores?.eating_rhythm ?? 0} />
          <ScoreCard label="Diet Wholeness" score={scores?.diet_wholeness ?? 0} />
        </View>
      </Card>

      <Card style={styles.section}>
        <Text style={styles.sectionTitle}>Macros</Text>
        <View style={styles.ringRow}>
          <MacroRing label="Protein" value={totals?.protein_g ?? 0} target={goal?.protein_g ?? 150} color={Colors.accent.teal} />
          <MacroRing label="Carbs" value={totals?.carbs_g ?? 0} target={goal?.carbs_g ?? 200} color={Colors.accent.blue} />
          <MacroRing label="Fat" value={totals?.fat_g ?? 0} target={goal?.fat_g ?? 70} color={Colors.accent.amber} />
          <MacroRing label="Calories" value={totals?.calories ?? 0} target={goal?.calories_target ?? 2000} unit="" color={Colors.accent.purple} />
        </View>
      </Card>

      <Text style={styles.sectionTitle}>Today's meals</Text>
      <FlatList
        horizontal
        data={logs}
        keyExtractor={(l) => l.id}
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.mealRow}
        renderItem={({ item }) => <MealCard log={item} onPress={() => router.push(`/log/meal/${item.id}`)} />}
        ListEmptyComponent={<Text style={styles.empty}>No meals logged yet today.</Text>}
        ListFooterComponent={
          <Card onPress={() => router.push("/(tabs)/scan")} style={styles.addCard}>
            <Text style={styles.addPlus}>＋</Text>
            <Text style={styles.addText}>Add meal</Text>
          </Card>
        }
      />

      <Text style={styles.sectionTitle}>Streaks</Text>
      <FlatList
        horizontal
        data={streaks}
        keyExtractor={(s) => s.type}
        showsHorizontalScrollIndicator={false}
        renderItem={({ item }) => <StreakPill streak={item} />}
      />

      <Card style={styles.coachCard} onPress={() => router.push("/(tabs)/coach")}>
        <Text style={styles.coachAvatar}>🤖</Text>
        <Text style={styles.coachText}>{insight.data?.insight ?? "Loading your daily tip…"}</Text>
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 8, paddingBottom: 40 },
  greeting: { color: Colors.text.primary, fontSize: 24, fontWeight: "800", marginBottom: 8 },
  section: { marginBottom: 8 },
  sectionTitle: { color: Colors.text.primary, fontSize: 16, fontWeight: "700", marginVertical: 8 },
  scoreRow: { flexDirection: "row", justifyContent: "space-between", marginTop: 8 },
  ringRow: { flexDirection: "row", justifyContent: "space-between", marginTop: 8 },
  mealRow: { paddingVertical: 4 },
  empty: { color: Colors.text.secondary, paddingVertical: 20 },
  addCard: { width: 120, alignItems: "center", justifyContent: "center" },
  addPlus: { color: Colors.accent.teal, fontSize: 32, fontWeight: "800" },
  addText: { color: Colors.text.secondary, marginTop: 4 },
  coachCard: { flexDirection: "row", alignItems: "center", gap: 12, marginTop: 16 },
  coachAvatar: { fontSize: 28 },
  coachText: { color: Colors.text.primary, flex: 1, lineHeight: 20 },
});
