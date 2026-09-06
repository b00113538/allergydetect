import * as Print from "expo-print";
import * as Sharing from "expo-sharing";
import { useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";
import { generateAllergyCard } from "@/lib/translation";
import { useAuthStore } from "@/store/auth";
import type { AllergyCard } from "@/types";

export default function TravelCardScreen() {
  const allergies = useAuthStore((s) => s.allergies);
  const [languages, setLanguages] = useState<{ code: string; name: string }[]>([]);
  const [lang, setLang] = useState("es");
  const [card, setCard] = useState<AllergyCard | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    void api.languages().then(setLanguages).catch(() => setLanguages([]));
  }, []);

  const generate = async () => {
    setLoading(true);
    try {
      const sev: Record<string, string> = {};
      allergies.forEach((a) => (sev[a.allergen_name] = a.severity));
      const result = await generateAllergyCard(allergies.map((a) => a.allergen_name), lang, sev);
      setCard(result);
    } catch {
      setCard(null);
    } finally {
      setLoading(false);
    }
  };

  const exportPdf = async () => {
    if (!card) return;
    const html = `<html><body style="font-family:sans-serif;padding:24px">
      <h2>${card.allergen_statements.map((s) => s.translated_statement).join("<br/>")}</h2>
      <p style="background:#fee;padding:12px;border-radius:8px">${card.emergency_phrase}</p>
    </body></html>`;
    const { uri } = await Print.printToFileAsync({ html });
    if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Translate your allergy card</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.langRow}>
        {languages.map((l) => (
          <Pressable key={l.code} onPress={() => setLang(l.code)} style={[styles.langChip, lang === l.code && styles.langActive]}>
            <Text style={[styles.langText, lang === l.code && styles.langTextActive]}>{l.name}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <Button title="Generate card" onPress={generate} loading={loading} />

      {card && (
        <Card style={styles.card}>
          {card.allergen_statements.map((s, i) => (
            <Text key={i} style={styles.statement}>
              {s.translated_statement}
            </Text>
          ))}
          <View style={styles.emergency}>
            <Text style={styles.emergencyText}>{card.emergency_phrase}</Text>
          </View>
          <Button title="Export / Print PDF" variant="secondary" onPress={exportPdf} style={{ marginTop: 12 }} />
        </Card>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16, gap: 12 },
  title: { color: Colors.text.primary, fontSize: 20, fontWeight: "800" },
  langRow: { gap: 8, paddingVertical: 4 },
  langChip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: Colors.bg.card },
  langActive: { backgroundColor: Colors.accent.teal },
  langText: { color: Colors.text.secondary, fontWeight: "600" },
  langTextActive: { color: Colors.text.inverse },
  card: { gap: 8 },
  statement: { color: Colors.text.primary, fontSize: 16, lineHeight: 24 },
  emergency: { backgroundColor: Colors.allergen.confirmed.bg, borderRadius: 10, padding: 14, marginTop: 8 },
  emergencyText: { color: Colors.allergen.confirmed.text, fontSize: 16, fontWeight: "700" },
});
