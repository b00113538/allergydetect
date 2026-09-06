import { StyleSheet, Text, View } from "react-native";

import { AllergenBadge } from "@/components/ui/AllergenBadge";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import type { CommunityRecipe } from "@/lib/api";

export function RecipeCard({ recipe, onPress }: { recipe: CommunityRecipe; onPress?: () => void }) {
  const macros = recipe.macros ?? {};
  return (
    <Card onPress={onPress} style={styles.card}>
      <Text style={styles.title}>{recipe.name}</Text>
      <Text style={styles.meta}>
        {recipe.ingredients?.length ?? 0} ingredients · used {recipe.use_count}×
      </Text>
      <View style={styles.macros}>
        <Text style={styles.macroItem}>{Math.round(macros.calories ?? 0)} kcal</Text>
        <Text style={styles.macroItem}>P {Math.round(macros.protein_g ?? 0)}</Text>
        <Text style={styles.macroItem}>C {Math.round(macros.carbs_g ?? 0)}</Text>
        <Text style={styles.macroItem}>F {Math.round(macros.fat_g ?? 0)}</Text>
      </View>
      {recipe.allergen_tags.length > 0 && (
        <View style={styles.tags}>
          {recipe.allergen_tags.map((t) => (
            <AllergenBadge key={t} label={t} status="probable" />
          ))}
        </View>
      )}
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { marginBottom: 10, gap: 6 },
  title: { color: Colors.text.primary, fontSize: 17, fontWeight: "700", textTransform: "capitalize" },
  meta: { color: Colors.text.secondary, fontSize: 12 },
  macros: { flexDirection: "row", gap: 12, marginTop: 6 },
  macroItem: { color: Colors.accent.tealLight, fontWeight: "700", fontSize: 13 },
  tags: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginTop: 4 },
});
