import { useQuery } from "@tanstack/react-query";
import { useLocalSearchParams } from "expo-router";
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from "react-native";

import { ForumThread } from "@/components/community/ForumThread";
import { Colors } from "@/constants/colors";
import { api } from "@/lib/api";

export default function ForumPost() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const feed = useQuery({ queryKey: ["community-feed"], queryFn: () => api.communityFeed() });
  const post = feed.data?.find((p) => p.id === id);

  if (feed.isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={Colors.accent.teal} />
      </View>
    );
  }

  if (!post) {
    return (
      <View style={styles.center}>
        <Text style={styles.muted}>Post not found.</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <ForumThread post={post} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  content: { padding: 16 },
  center: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: Colors.bg.primary },
  muted: { color: Colors.text.secondary },
});
