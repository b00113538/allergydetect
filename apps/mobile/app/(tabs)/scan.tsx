import { CameraView } from "expo-camera";
import { useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { GradeBadge } from "@/components/ui/GradeBadge";
import { AllergenBadge } from "@/components/ui/AllergenBadge";
import { FoodGradeRadar } from "@/components/food/FoodGradeRadar";
import { Colors } from "@/constants/colors";
import { useBarcode } from "@/hooks/useBarcode";
import { useCamera } from "@/hooks/useCamera";
import { useCreateFoodLog } from "@/hooks/useFoodLog";
import { api } from "@/lib/api";
import type { CameraScanResult, MealType } from "@/types";

type Mode = "camera" | "barcode" | "manual";

export default function Scan() {
  const { granted, requestPermission, pickFromGallery } = useCamera();
  const camRef = useRef<CameraView>(null);
  const [mode, setMode] = useState<Mode>("camera");
  const [analyzing, setAnalyzing] = useState(false);
  const [result, setResult] = useState<CameraScanResult | null>(null);
  const [query, setQuery] = useState("");
  const barcode = useBarcode();
  const createLog = useCreateFoodLog();

  const analyze = async (uri: string) => {
    setAnalyzing(true);
    try {
      const res = await api.scanCamera(uri);
      setResult(res);
    } catch {
      Alert.alert("Scan unavailable", "The AI scanner needs an OpenAI key configured on the server.");
    } finally {
      setAnalyzing(false);
    }
  };

  const capture = async () => {
    const photo = await camRef.current?.takePictureAsync({ quality: 0.7 });
    if (photo?.uri) await analyze(photo.uri);
  };

  const logScan = async (mealType: MealType) => {
    if (!result) return;
    await createLog.mutateAsync({
      meal_type: mealType,
      source: "camera",
      food_image_url: result.image_url,
      items: result.analysis.ingredients.map((i) => ({
        ingredient_name: i.name,
        quantity_g: i.quantity_estimate_g || 100,
        calories: (i.calories_per_100g * (i.quantity_estimate_g || 100)) / 100,
        protein_g: (i.protein_g_per_100g * (i.quantity_estimate_g || 100)) / 100,
        carbs_g: (i.carbs_g_per_100g * (i.quantity_estimate_g || 100)) / 100,
        fat_g: (i.fat_g_per_100g * (i.quantity_estimate_g || 100)) / 100,
        fiber_g: (i.fiber_g_per_100g * (i.quantity_estimate_g || 100)) / 100,
        allergen_flags: i.common_allergen_category ? [i.common_allergen_category] : [],
        confidence_score: i.confidence_score,
      })),
    });
    setResult(null);
    Alert.alert("Logged", "Meal added to today's log.");
  };

  if (!granted) {
    return (
      <View style={styles.center}>
        <Text style={styles.permText}>AllergyDetect needs camera access to scan food and barcodes.</Text>
        <Button title="Grant camera access" onPress={requestPermission} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.modeRow}>
        {(["camera", "barcode", "manual"] as Mode[]).map((m) => (
          <Pressable key={m} onPress={() => setMode(m)} style={[styles.modeChip, mode === m && styles.modeChipActive]}>
            <Text style={[styles.modeText, mode === m && styles.modeTextActive]}>{m}</Text>
          </Pressable>
        ))}
      </View>

      {mode === "manual" ? (
        <ScrollView contentContainerStyle={styles.manual}>
          <TextInput
            style={styles.input}
            placeholder="e.g. 2 eggs and toast"
            placeholderTextColor={Colors.text.tertiary}
            value={query}
            onChangeText={setQuery}
          />
          <Button
            title="Search nutrition"
            onPress={async () => {
              try {
                const res = await api.scanText(query);
                Alert.alert("Result", JSON.stringify(res.items?.[0]?.macros_per_serving ?? res, null, 2).slice(0, 300));
              } catch {
                Alert.alert("Unavailable", "Text search needs Nutritionix credentials on the server.");
              }
            }}
          />
        </ScrollView>
      ) : (
        <View style={styles.cameraWrap}>
          <CameraView
            ref={camRef}
            style={StyleSheet.absoluteFill}
            barcodeScannerSettings={mode === "barcode" ? { barcodeTypes: ["ean13", "ean8", "upc_a", "upc_e"] } : undefined}
            onBarcodeScanned={
              mode === "barcode" && !barcode.scanned
                ? (e) => void barcode.lookup(e.data)
                : undefined
            }
          />
          {mode === "camera" && (
            <View style={styles.captureBar}>
              <Pressable onPress={pickFromGallery} style={styles.smallBtn}>
                <Text style={styles.smallBtnText}>🖼️</Text>
              </Pressable>
              <Pressable onPress={capture} style={styles.captureBtn} />
              <View style={styles.smallBtn} />
            </View>
          )}
          {analyzing && (
            <View style={styles.overlay}>
              <ActivityIndicator color={Colors.accent.teal} size="large" />
              <Text style={styles.overlayText}>AI analysing your plate…</Text>
            </View>
          )}
        </View>
      )}

      {(result || barcode.product) && (
        <ScrollView style={styles.sheet} contentContainerStyle={{ padding: 16, gap: 10 }}>
          {result && (
            <>
              <View style={styles.sheetHeader}>
                <GradeBadge grade={result.grade.grade} />
                <Text style={styles.sheetTitle}>{result.analysis.identified_dishes.join(", ") || "Scan result"}</Text>
              </View>
              {result.allergen_matches.length > 0 && (
                <Card style={styles.warnCard}>
                  <Text style={styles.warnTitle}>⚠ Allergen warning</Text>
                  {result.allergen_matches.map((m, i) => (
                    <Text key={i} style={styles.warnItem}>
                      {m.allergen} ({m.severity})
                    </Text>
                  ))}
                </Card>
              )}
              <View style={styles.chipWrap}>
                {result.analysis.ingredients.map((ing, i) => (
                  <AllergenBadge
                    key={i}
                    label={`${ing.name} ${Math.round(ing.confidence_score * 100)}%`}
                    status={ing.is_allergen_candidate ? "probable" : "safe"}
                  />
                ))}
              </View>
              <Card>
                <FoodGradeRadar breakdown={result.grade.breakdown} />
              </Card>
              <View style={styles.mealBtns}>
                {(["breakfast", "lunch", "dinner", "snack"] as MealType[]).map((mt) => (
                  <Button key={mt} title={mt} variant="secondary" onPress={() => logScan(mt)} style={{ flex: 1 }} />
                ))}
              </View>
            </>
          )}
          {barcode.product && barcode.product.found && (
            <>
              <View style={styles.sheetHeader}>
                <GradeBadge grade={barcode.product.grade?.grade} />
                <Text style={styles.sheetTitle}>{barcode.product.name}</Text>
              </View>
              <Text style={styles.meta}>
                NutriScore {barcode.product.nutriscore ?? "?"} · NOVA {barcode.product.nova_group ?? "?"}
              </Text>
              {(barcode.product.allergen_matches ?? []).map((m, i) => (
                <AllergenBadge key={i} label={m.allergen} status="confirmed" />
              ))}
              <Button title="Add to log (lunch)" onPress={async () => {
                const p = barcode.product!;
                const m = p.macros_per_100g ?? {};
                await createLog.mutateAsync({
                  meal_type: "lunch",
                  source: "barcode",
                  items: [{
                    ingredient_name: p.name ?? "Product",
                    quantity_g: 100,
                    calories: m.calories ?? 0,
                    protein_g: m.protein_g ?? 0,
                    carbs_g: m.carbs_g ?? 0,
                    fat_g: m.fat_g ?? 0,
                    fiber_g: m.fiber_g ?? 0,
                    allergen_flags: p.allergens ?? [],
                    confidence_score: 1,
                    nova_group: p.nova_group ?? null,
                  }],
                });
                barcode.reset();
                Alert.alert("Logged", "Product added to today's log.");
              }} />
            </>
          )}
          {barcode.product && !barcode.product.found && (
            <Text style={styles.meta}>Product not found. Try manual entry.</Text>
          )}
          <Button title="Close" variant="ghost" onPress={() => { setResult(null); barcode.reset(); }} />
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  center: { flex: 1, padding: 24, alignItems: "center", justifyContent: "center", gap: 16, backgroundColor: Colors.bg.primary },
  permText: { color: Colors.text.secondary, textAlign: "center", fontSize: 15 },
  modeRow: { flexDirection: "row", gap: 8, padding: 12 },
  modeChip: { flex: 1, paddingVertical: 10, borderRadius: 10, backgroundColor: Colors.bg.card, alignItems: "center" },
  modeChipActive: { backgroundColor: Colors.accent.teal },
  modeText: { color: Colors.text.secondary, fontWeight: "700", textTransform: "capitalize" },
  modeTextActive: { color: Colors.text.inverse },
  cameraWrap: { flex: 1, margin: 12, borderRadius: 18, overflow: "hidden" },
  captureBar: { position: "absolute", bottom: 24, left: 0, right: 0, flexDirection: "row", alignItems: "center", justifyContent: "space-around" },
  captureBtn: { width: 72, height: 72, borderRadius: 36, backgroundColor: "#fff", borderWidth: 4, borderColor: Colors.accent.teal },
  smallBtn: { width: 48, height: 48, borderRadius: 24, backgroundColor: "#00000066", alignItems: "center", justifyContent: "center" },
  smallBtnText: { fontSize: 20 },
  overlay: { ...StyleSheet.absoluteFillObject, backgroundColor: "#000000aa", alignItems: "center", justifyContent: "center", gap: 12 },
  overlayText: { color: Colors.text.primary, fontWeight: "600" },
  manual: { padding: 16, gap: 12 },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, paddingHorizontal: 16, height: 52, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border },
  sheet: { maxHeight: "55%", backgroundColor: Colors.bg.card, borderTopLeftRadius: 24, borderTopRightRadius: 24 },
  sheetHeader: { flexDirection: "row", alignItems: "center", gap: 12 },
  sheetTitle: { color: Colors.text.primary, fontSize: 18, fontWeight: "800", flex: 1, textTransform: "capitalize" },
  meta: { color: Colors.text.secondary, fontSize: 14 },
  warnCard: { backgroundColor: Colors.allergen.confirmed.bg, borderColor: Colors.allergen.confirmed.border },
  warnTitle: { color: Colors.allergen.confirmed.text, fontWeight: "800", marginBottom: 4 },
  warnItem: { color: Colors.allergen.confirmed.text, textTransform: "capitalize" },
  chipWrap: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  mealBtns: { flexDirection: "row", gap: 6 },
});
