import { StyleSheet, Text, View } from "react-native";

import { Badge } from "@/components/ui/Badge";
import { Card } from "@/components/ui/Card";
import { Colors } from "@/constants/colors";
import type { CommunityPost } from "@/lib/api";

export function ForumThread({ post }: { post: CommunityPost }) {
  return (
    <Card style={styles.card}>
      <View style={styles.header}>
        <Badge label={post.post_type} color={Colors.accent.tealLight} bg={Colors.bg.elevated} />
        <Text style={styles.meta}>
          {post.is_anonymous ? "anonymous" : "member"} · {new Date(post.created_at).toLocaleString()}
        </Text>
      </View>
      {post.title && <Text style={styles.title}>{post.title}</Text>}
      <Text style={styles.body}>{post.content}</Text>
      <View style={styles.footer}>
        <Text style={styles.upvotes}>▲ {post.upvotes} upvotes</Text>
        {post.allergen_tags.map((t) => (
          <Text key={t} style={styles.tag}>
            #{t}
          </Text>
        ))}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { gap: 10 },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  meta: { color: Colors.text.tertiary, fontSize: 11 },
  title: { color: Colors.text.primary, fontSize: 22, fontWeight: "800" },
  body: { color: Colors.text.primary, fontSize: 15, lineHeight: 22 },
  footer: { flexDirection: "row", gap: 12, alignItems: "center", flexWrap: "wrap" },
  upvotes: { color: Colors.accent.tealLight, fontWeight: "700" },
  tag: { color: Colors.accent.tealLight, fontSize: 12 },
});
