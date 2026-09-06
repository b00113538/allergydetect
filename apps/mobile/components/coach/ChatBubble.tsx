import { StyleSheet, Text, View } from "react-native";

import { Colors } from "@/constants/colors";
import type { ChatMessage } from "@/hooks/useCoach";

export function ChatBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === "user";
  return (
    <View style={[styles.row, isUser ? styles.rowUser : styles.rowAi]}>
      {!isUser && (
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>🤖</Text>
        </View>
      )}
      <View style={[styles.bubble, isUser ? styles.user : styles.ai]}>
        <Text style={[styles.text, isUser && styles.userText]}>
          {message.text || "…"}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", marginVertical: 6, alignItems: "flex-end", gap: 8 },
  rowUser: { justifyContent: "flex-end" },
  rowAi: { justifyContent: "flex-start" },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: `${Colors.accent.teal}33`,
    alignItems: "center",
    justifyContent: "center",
  },
  avatarText: { fontSize: 16 },
  bubble: { maxWidth: "78%", borderRadius: 16, paddingHorizontal: 14, paddingVertical: 10 },
  ai: { backgroundColor: Colors.bg.card, borderWidth: 1, borderColor: Colors.border },
  user: { backgroundColor: Colors.accent.teal },
  text: { color: Colors.text.primary, fontSize: 15, lineHeight: 21 },
  userText: { color: Colors.text.inverse },
});
