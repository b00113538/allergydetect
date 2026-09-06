import * as Speech from "expo-speech";
import { useState } from "react";
import { Modal, Pressable, StyleSheet, Text, TextInput, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";

interface Props {
  onTranscribed: (text: string) => void;
}

/**
 * Voice input via the platform keyboard's built-in dictation.
 *
 * On-device streaming speech-to-text needs a native module (e.g.
 * `@react-native-voice/voice`) and a custom dev build. In Expo Go we open a
 * text field and prompt the user to tap their keyboard's microphone — that
 * routes through the OS speech recogniser and is reliable across both
 * platforms without extra dependencies.
 */
export function VoiceInput({ onTranscribed }: Props) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState("");

  const start = () => {
    setDraft("");
    setOpen(true);
    Speech.speak("Listening", { rate: 1.1 });
  };

  const submit = () => {
    const text = draft.trim();
    setOpen(false);
    if (text) onTranscribed(text);
  };

  return (
    <>
      <Pressable onPress={start} style={styles.mic} accessibilityLabel="Voice input">
        <Text style={styles.micIcon}>🎙️</Text>
      </Pressable>
      <Modal visible={open} transparent animationType="slide" onRequestClose={() => setOpen(false)}>
        <View style={styles.bg}>
          <View style={styles.sheet}>
            <Text style={styles.title}>Dictate your message</Text>
            <Text style={styles.hint}>Tap the microphone on your keyboard, speak, then tap Send.</Text>
            <TextInput
              style={styles.input}
              autoFocus
              multiline
              placeholder="Listening…"
              placeholderTextColor={Colors.text.tertiary}
              value={draft}
              onChangeText={setDraft}
            />
            <Button title="Send" onPress={submit} />
            <Button title="Cancel" variant="ghost" onPress={() => setOpen(false)} />
          </View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  mic: { width: 48, height: 48, borderRadius: 24, backgroundColor: Colors.bg.elevated, alignItems: "center", justifyContent: "center" },
  micIcon: { fontSize: 22 },
  bg: { flex: 1, justifyContent: "flex-end", backgroundColor: "#000000aa" },
  sheet: { backgroundColor: Colors.bg.card, padding: 20, borderTopLeftRadius: 24, borderTopRightRadius: 24, gap: 10 },
  title: { color: Colors.text.primary, fontSize: 20, fontWeight: "800" },
  hint: { color: Colors.text.secondary, fontSize: 13 },
  input: { backgroundColor: Colors.bg.input, borderRadius: 12, padding: 14, color: Colors.text.primary, borderWidth: 1, borderColor: Colors.border, minHeight: 80, textAlignVertical: "top" },
});
