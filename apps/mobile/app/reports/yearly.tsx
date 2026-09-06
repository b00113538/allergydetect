import { useQuery } from "@tanstack/react-query";
import * as Sharing from "expo-sharing";
import { useRef, useState } from "react";
import { Dimensions, FlatList, Pressable, StyleSheet, Text, View, type ViewToken } from "react-native";

import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";

interface Wrapped {
  total_meals_logged: number;
  total_scans: number;
  longest_reaction_free_streak: number;
  most_eaten_food: string | null;
  top_allergen_discovered: string | null;
  best_month: number | null;
  total_badges_earned: number;
}

const MONTHS = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

interface CardSpec {
  title: string;
  value: string;
  sub?: string;
  bg: string;
  accent: string;
}

function buildCards(w: Wrapped): CardSpec[] {
  return [
    { title: "You logged this many meals", value: `${w.total_meals_logged}`, sub: "Every entry sharpens your allergy insights.", bg: Colors.accent.teal, accent: Colors.text.inverse },
    { title: "Top allergen discovery", value: w.top_allergen_discovered ?? "—", sub: "Most likely trigger we surfaced.", bg: Colors.accent.coral, accent: Colors.text.inverse },
    { title: "Longest reaction-free streak", value: `${w.longest_reaction_free_streak} days`, sub: "Symptom-free days in a row.", bg: Colors.accent.blue, accent: Colors.text.inverse },
    { title: "Most-eaten food", value: w.most_eaten_food ?? "—", sub: "Your go-to ingredient this year.", bg: Colors.accent.purple, accent: Colors.text.inverse },
    { title: "Best month", value: w.best_month ? MONTHS[w.best_month] : "—", sub: "Highest logging activity.", bg: Colors.accent.amber, accent: Colors.text.inverse },
    { title: "Badges earned", value: `${w.total_badges_earned}`, sub: "Tap share to brag.", bg: Colors.bg.elevated, accent: Colors.text.primary },
  ];
}

const { width } = Dimensions.get("window");

export default function YearlyWrapped() {
  const wrapped = useQuery({ queryKey: ["yearly-wrapped"], queryFn: () => api.yearlyWrapped() as Promise<Wrapped> });
  const [index, setIndex] = useState(0);
  const listRef = useRef<FlatList<CardSpec>>(null);

  const cards = wrapped.data ? buildCards(wrapped.data) : [];

  const share = async () => {
    if (await Sharing.isAvailableAsync()) {
      await Sharing.shareAsync("https://allergydetect.app", { dialogTitle: "My AllergyDetect Wrapped" });
    }
  };

  const onViewable = useRef(({ viewableItems }: { viewableItems: ViewToken[] }) => {
    if (viewableItems[0]?.index != null) setIndex(viewableItems[0].index);
  }).current;

  if (cards.length === 0) {
    return (
      <View style={styles.loading}>
        <Text style={styles.loadingText}>Crunching your year…</Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <FlatList
        ref={listRef}
        data={cards}
        keyExtractor={(_, i) => String(i)}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onViewableItemsChanged={onViewable}
        viewabilityConfig={{ itemVisiblePercentThreshold: 60 }}
        renderItem={({ item, index: i }) => (
          <View style={[styles.card, { width, backgroundColor: item.bg }]}>
            <Text style={[styles.badge, { color: item.accent }]}>{i + 1} / {cards.length}</Text>
            <Text style={[styles.title, { color: item.accent }]}>{item.title}</Text>
            <Text style={[styles.value, { color: item.accent }]}>{item.value}</Text>
            {item.sub && <Text style={[styles.sub, { color: item.accent }]}>{item.sub}</Text>}
            {i === cards.length - 1 && (
              <Pressable onPress={share} style={[styles.shareBtn, { borderColor: item.accent }]}>
                <Text style={[styles.shareText, { color: item.accent }]}>Share Wrapped</Text>
              </Pressable>
            )}
          </View>
        )}
      />
      <View style={styles.dots}>
        {cards.map((_, i) => (
          <View key={i} style={[styles.dot, i === index && styles.dotActive]} />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: Colors.bg.primary },
  loadingText: { color: Colors.text.secondary },
  card: { flex: 1, padding: 32, justifyContent: "center", gap: 14 },
  badge: { fontWeight: "700", opacity: 0.8 },
  title: { fontSize: 22, fontWeight: "700", opacity: 0.85 },
  value: { fontSize: 56, fontWeight: "900", textTransform: "capitalize" },
  sub: { fontSize: 16, opacity: 0.85, lineHeight: 22 },
  shareBtn: { marginTop: 28, padding: 14, borderWidth: 2, borderRadius: 14, alignSelf: "flex-start" },
  shareText: { fontWeight: "800", fontSize: 16 },
  dots: { position: "absolute", bottom: 28, alignSelf: "center", flexDirection: "row", gap: 6 },
  dot: { width: 7, height: 7, borderRadius: 4, backgroundColor: "#ffffff66" },
  dotActive: { backgroundColor: "#fff", width: 18 },
});
