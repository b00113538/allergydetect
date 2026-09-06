import { useRouter } from "expo-router";
import { useState } from "react";
import { Alert, KeyboardAvoidingView, Platform, StyleSheet, Text, TextInput } from "react-native";

import { Button } from "@/components/ui/Button";
import { Colors } from "@/constants/colors";
import { useAuthStore } from "@/store/auth";

export default function Login() {
  const router = useRouter();
  const login = useAuthStore((s) => s.login);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const onSubmit = async () => {
    setLoading(true);
    try {
      await login(email.trim().toLowerCase(), password);
      router.replace("/");
    } catch {
      Alert.alert("Login failed", "Invalid email or password.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <Text style={styles.title}>Welcome back</Text>
      <TextInput style={styles.input} placeholder="Email" placeholderTextColor={Colors.text.tertiary} autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
      <TextInput style={styles.input} placeholder="Password" placeholderTextColor={Colors.text.tertiary} secureTextEntry value={password} onChangeText={setPassword} />
      <Button title="Log in" onPress={onSubmit} loading={loading} style={{ marginTop: 8 }} />
      <Button title="Create an account" variant="ghost" onPress={() => router.push("/(auth)/register")} />
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
