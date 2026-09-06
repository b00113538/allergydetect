import { useQuery } from "@tanstack/react-query";
import { useLocalSearchParams } from "expo-router";
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from "react-native";

import { AllergenBadge } from "@/components/ui/AllergenBadge";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";

export default function RecipeDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const recipes = useQuery({ queryKey: ["community-recipes"], queryFn: () => api.listRecipes() });
  const recipe = recipes.data?.find((r) => r.id === id);

  if (recipes.isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={Colors.accent.teal} />
      </View>
    );
  }

  if (!recipe) {
    return (
      <View style={styles.center}>
        <Text style={styles.muted}>Recipe not found.</Text>
      </View>
    );
  }

  const m = recipe.macros ?? {};

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>{recipe.name}</Text>
      <Text style={styles.meta}>used {recipe.use_count}× by the community</Text>

      <Card style={styles.macroCard}>
        <View style={styles.row}>
          <Stat label="Calories" value={Math.round(m.calories ?? 0)} />
          <Stat label="Protein" value={`${Math.round(m.protein_g ?? 0)}g`} />
          <Stat label="Carbs" value={`${Math.round(m.carbs_g ?? 0)}g`} />
          <Stat label="Fat" value={`${Math.round(m.fat_g ?? 0)}g`} />
        </View>
      </Card>

      <Card>
        <Text style={styles.section}>Ingredients</Text>
        {recipe.ingredients?.map((ing, i) => (
          <Text key={i} style={styles.ingredient}>
            • {ing.name}
            {ing.quantity_g ? ` (${ing.quantity_g}g)` : ""}
          </Text>
        ))}
      </Card>

      {recipe.allergen_tags.length > 0 && (
        <Card>
          <Text style={styles.section}>Contains</Text>
          <View style={styles.chips}>
            {recipe.allergen_tags.map((t) => (
              <AllergenBadge key={t} label={t} status="probable" />
            ))}
          </View>
        </Card>
      )}
    </ScrollView>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  center: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: Colors.bg.primary },
  muted: { color: Colors.text.secondary },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", textTransform: "capitalize" },
  meta: { color: Colors.text.secondary, fontSize: 13 },
  macroCard: { marginVertical: 4 },
  row: { flexDirection: "row", justifyContent: "space-around" },
  stat: { alignItems: "center" },
  statValue: { color: Colors.accent.tealLight, fontSize: 20, fontWeight: "800" },
  statLabel: { color: Colors.text.tertiary, fontSize: 11, marginTop: 2 },
  section: { color: Colors.text.primary, fontWeight: "800", marginBottom: 8 },
  ingredient: { color: Colors.text.secondary, marginVertical: 2, textTransform: "capitalize" },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
