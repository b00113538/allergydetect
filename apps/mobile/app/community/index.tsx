import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "expo-router";
import { useState } from "react";
import { Alert, FlatList, Modal, Pressable, StyleSheet, Text, TextInput, View } from "react-native";

import { PostCard } from "@/components/community/PostCard";
import { RecipeCard } from "@/components/community/RecipeCard";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import { api, type CommunityPost, type CommunityRecipe } from "@/lib/api";

type Tab = "feed" | "recipes";

export default function CommunityIndex() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("feed");
  const [composing, setComposing] = useState(false);
  const qc = useQueryClient();

  const feed = useQuery({ queryKey: ["community-feed"], queryFn: () => api.communityFeed() });
  const recipes = useQuery({ queryKey: ["community-recipes"], queryFn: () => api.listRecipes() });

  const upvote = useMutation({
    mutationFn: (id: string) => api.upvotePost(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["community-feed"] }),
  });

  return (
    <View style={styles.container}>
      <View style={styles.tabs}>
        {(["feed", "recipes"] as Tab[]).map((t) => (
          <Pressable key={t} onPress={() => setTab(t)} style={[styles.tab, tab === t && styles.tabActive]}>
            <Text style={[styles.tabText, tab === t && styles.tabTextActive]}>{t}</Text>
          </Pressable>
        ))}
      </View>

      {tab === "feed" ? (
        <FlatList<CommunityPost>
          data={feed.data ?? []}
          keyExtractor={(p) => p.id}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <PostCard
              post={item}
              onPress={() => router.push(`/community/forum/${item.id}`)}
              onUpvote={() => upvote.mutate(item.id)}
            />
          )}
          ListEmptyComponent={<Text style={styles.empty}>No posts yet. Be the first.</Text>}
          refreshing={feed.isFetching}
          onRefresh={() => feed.refetch()}
        />
      ) : (
        <FlatList<CommunityRecipe>
          data={recipes.data ?? []}
          keyExtractor={(r) => r.id}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <RecipeCard recipe={item} onPress={() => router.push(`/community/recipe/${item.id}`)} />
          )}
          ListEmptyComponent={<Text style={styles.empty}>No public recipes yet.</Text>}
          refreshing={recipes.isFetching}
          onRefresh={() => recipes.refetch()}
        />
      )}

      <Pressable onPress={() => setComposing(true)} style={styles.fab}>
        <Text style={styles.fabText}>＋</Text>
      </Pressable>

      <ComposerModal visible={composing} onClose={() => setComposing(false)} tab={tab} />
    </View>
  );
}

function ComposerModal({ visible, onClose, tab }: { visible: boolean; onClose: () => void; tab: Tab }) {
  const [postType, setPostType] = useState("tip");
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [tags, setTags] = useState("");
  const [saving, setSaving] = useState(false);
  const qc = useQueryClient();

  const submit = async () => {
    setSaving(true);
    try {
      const tagList = tags.split(",").map((t) => t.trim()).filter(Boolean);
      if (tab === "recipes") {
        await api.createRecipe({
          name: title || "Untitled recipe",
          ingredients: content.split("\n").map((line) => ({ name: line.trim() })).filter((i) => i.name),
          allergen_tags: tagList,
        });
        qc.invalidateQueries({ queryKey: ["community-recipes"] });
      } else {
        await api.createCommunityPost({ post_type: postType, title, content, allergen_tags: tagList });
        qc.invalidateQueries({ queryKey: ["community-feed"] });
      }
      onClose();
      setTitle("");
      setContent("");
      setTags("");
    } catch {
      Alert.alert("Couldn't post", "Try again in a moment.");
    } finally {
      setSaving(false);
    }
  };

  const types = ["tip", "question", "story", "warning"];

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalBg}>
        <Card style={styles.modal}>
          <Text style={styles.modalTitle}>{tab === "recipes" ? "Share a recipe" : "New post"}</Text>
          {tab === "feed" && (
            <View style={styles.typeRow}>
              {types.map((t) => (
                <Pressable key={t} onPress={() => setPostType(t)} style={[styles.typeChip, postType === t && styles.typeChipActive]}>
                  <Text style={[styles.typeText, postType === t && styles.typeTextActive]}>{t}</Text>
                </Pressable>
              ))}
            </View>
          )}
          <TextInput
            style={styles.input}
            placeholder={tab === "recipes" ? "Recipe name" : "Title (optional)"}
            placeholderTextColor={Colors.text.tertiary}
            value={title}
            onChangeText={setTitle}
          />
          <TextInput
            style={[styles.input, styles.textarea]}
            placeholder={tab === "recipes" ? "Ingredients, one per line" : "What's on your mind?"}
            placeholderTextColor={Colors.text.tertiary}
            value={content}
            onChangeText={setContent}
            multiline
          />
          <TextInput
            style={styles.input}
            placeholder="Allergen tags, comma-separated (e.g. peanuts, gluten)"
            placeholderTextColor={Colors.text.tertiary}
            value={tags}
            onChangeText={setTags}
          />
          <Button title="Post" onPress={submit} loading={saving} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  tabs: { flexDirection: "row", gap: 8, padding: 12 },
  tab: { flex: 1, paddingVertical: 10, borderRadius: 10, backgroundColor: Colors.bg.card, alignItems: "center" },
  tabActive: { backgroundColor: Colors.accent.teal },
  tabText: { color: Colors.text.secondary, fontWeight: "700", textTransform: "capitalize" },
  tabTextActive: { color: Colors.text.inverse },
  list: { padding: 12 },
  empty: { color: Colors.text.secondary, textAlign: "center", padding: 24 },
  fab: { position: "absolute", right: 20, bottom: 28, width: 56, height: 56, borderRadius: 28, backgroundColor: Colors.accent.teal, alignItems: "center", justifyContent: "center" },
  fabText: { color: Colors.text.inverse, fontSize: 28, fontWeight: "800" },
  modalBg: { flex: 1, justifyContent: "flex-end", backgroundColor: "#000000aa" },
  modal: { gap: 10, borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 20, borderWidth: 0 },
  modalTitle: { color: Colors.text.primary, fontSize: 20, fontWeight: "800" },
  typeRow: { flexDirection: "row", gap: 6, flexWrap: "wrap" },
  typeChip: { paddingVertical: 6, paddingHorizontal: 12, borderRadius: 999, backgroundColor: Colors.bg.elevated },
  typeChipActive: { backgroundColor: Colors.accent.teal },
  typeText: { color: Colors.text.secondary, fontWeight: "600", textTransform: "capitalize" },
  typeTextActive: { color: Colors.text.inverse },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, padding: 14, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border },
  textarea: { minHeight: 100, textAlignVertical: "top" },
});
