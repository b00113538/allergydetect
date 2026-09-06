import { useState } from "react";
import {
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { ChatBubble } from "@/components/coach/ChatBubble";
import { QuickChips } from "@/components/coach/QuickChips";
import { VoiceInput } from "@/components/coach/VoiceInput";
import { Colors } from "@/constants/colors";
import { useCoach } from "@/hooks/useCoach";
import { useAuthStore } from "@/store/auth";

export default function Coach() {
  const user = useAuthStore((s) => s.user);
  const { messages, send, streaming, reset } = useCoach(user?.name?.split(" ")[0] ?? "there");
  const [text, setText] = useState("");

  const submit = (value?: string) => {
    const msg = (value ?? text).trim();
    if (!msg || streaming) return;
    setText("");
    void send(msg);
  };

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined} keyboardVerticalOffset={90}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>AI Coach</Text>
        <Pressable onPress={reset}>
          <Text style={styles.newChat}>New chat</Text>
        </Pressable>
      </View>
      <FlatList
        data={messages}
        keyExtractor={(m) => m.id}
        renderItem={({ item }) => <ChatBubble message={item} />}
        contentContainerStyle={styles.list}
      />
      <QuickChips onPick={(t) => submit(t)} />
      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          placeholder="Ask your coach…"
          placeholderTextColor={Colors.text.tertiary}
          value={text}
          onChangeText={setText}
          onSubmitEditing={() => submit()}
        />
        <VoiceInput onTranscribed={(t) => submit(t)} />
        <Pressable style={styles.send} onPress={() => submit()} disabled={streaming}>
          <Text style={styles.sendText}>➤</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg.primary },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", padding: 16 },
  headerTitle: { color: Colors.text.primary, fontSize: 20, fontWeight: "800" },
  newChat: { color: Colors.accent.tealLight, fontWeight: "600" },
  list: { padding: 16 },
  inputRow: { flexDirection: "row", gap: 8, padding: 12, alignItems: "center" },
  input: {
    flex: 1,
    backgroundColor: Colors.bg.input,
    borderRadius: 24,
    paddingHorizontal: 18,
    height: 48,
    color: Colors.text.primary,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  send: { width: 48, height: 48, borderRadius: 24, backgroundColor: Colors.accent.teal, alignItems: "center", justifyContent: "center" },
  sendText: { color: Colors.text.inverse, fontSize: 18, fontWeight: "800" },
});
