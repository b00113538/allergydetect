import { Pressable, StyleSheet, Text, View } from "react-native";

import { Badge } from "@/components/ui/Badge";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import type { CommunityPost } from "@/lib/api";

interface Props {
  post: CommunityPost;
  onPress?: () => void;
  onUpvote?: () => void;
}

const TYPE_COLOR: Record<string, string> = {
  question: Colors.accent.blue,
  tip: Colors.accent.teal,
  story: Colors.accent.purple,
  recipe: Colors.accent.amber,
  warning: Colors.accent.coral,
};

export function PostCard({ post, onPress, onUpvote }: Props) {
  const tint = TYPE_COLOR[post.post_type] ?? Colors.accent.tealLight;
  return (
    <Card onPress={onPress} style={styles.card}>
      <View style={styles.headerRow}>
        <Badge label={post.post_type} color={tint} bg={`${tint}20`} />
        <Text style={styles.date}>{new Date(post.created_at).toLocaleDateString()}</Text>
      </View>
      {post.title && <Text style={styles.title}>{post.title}</Text>}
      <Text style={styles.body} numberOfLines={3}>
        {post.content}
      </Text>
      {post.allergen_tags.length > 0 && (
        <View style={styles.tags}>
          {post.allergen_tags.map((t) => (
            <Text key={t} style={styles.tag}>
              #{t}
            </Text>
          ))}
        </View>
      )}
      <View style={styles.footer}>
        <Pressable onPress={onUpvote} style={styles.upvote}>
          <Text style={styles.upvoteText}>▲ {post.upvotes}</Text>
        </Pressable>
        {post.is_anonymous && <Text style={styles.anon}>anonymous</Text>}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { marginBottom: 10, gap: 8 },
  headerRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  date: { color: Colors.text.tertiary, fontSize: 11 },
  title: { color: Colors.text.primary, fontSize: 16, fontWeight: "700" },
  body: { color: Colors.text.secondary, fontSize: 14, lineHeight: 20 },
  tags: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  tag: { color: Colors.accent.tealLight, fontSize: 12 },
  footer: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  upvote: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 8, backgroundColor: Colors.bg.elevated },
  upvoteText: { color: Colors.accent.tealLight, fontWeight: "700" },
  anon: { color: Colors.text.tertiary, fontSize: 11 },
});
