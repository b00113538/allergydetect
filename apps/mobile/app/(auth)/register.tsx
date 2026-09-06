import { useRouter } from "expo-router";
import { useState } from "react";
import { Alert, KeyboardAvoidingView, Platform, StyleSheet, Text, TextInput, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";
import { useAuthStore } from "@/store/auth";

export default function Register() {
  const router = useRouter();
  const register = useAuthStore((s) => s.register);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const onSubmit = async () => {
    if (!name || !email || password.length < 8) {
      Alert.alert("Check your details", "Enter your name, a valid email, and an 8+ character password.");
      return;
    }
    setLoading(true);
    try {
      await register(email.trim().toLowerCase(), password, name.trim());
      router.replace("/(onboarding)/profile");
    } catch {
      Alert.alert("Registration failed", "That email may already be in use.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <Text style={styles.title}>Create your account</Text>
      <TextInput style={styles.input} placeholder="Full name" placeholderTextColor={Colors.text.tertiary} value={name} onChangeText={setName} />
      <TextInput style={styles.input} placeholder="Email" placeholderTextColor={Colors.text.tertiary} autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
      <TextInput style={styles.input} placeholder="Password (8+ chars)" placeholderTextColor={Colors.text.tertiary} secureTextEntry value={password} onChangeText={setPassword} />
      <Button title="Sign up" onPress={onSubmit} loading={loading} style={{ marginTop: 8 }} />
      <Button title="Back to login" variant="ghost" onPress={() => router.push("/(auth)/login")} />
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, justifyContent: "center", gap: 12, backgroundColor: Colors.bg.primary },
  title: { color: Colors.text.primary, fontSize: 26, fontWeight: "800", marginBottom: 12 },
  input: {
    backgroundColor: Colors.bg.input,
    borderRadius: 12,
    paddingHorizontal: 16,
    height: 52,
    color: Colors.text.primary,
    borderWidth: 1,
    borderColor: Colors.border,
  },
});
