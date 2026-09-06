import { ActivityIndicator, Pressable, StyleSheet, Text, ViewStyle } from "react-native";

import { Colors } from "@/constants/colors";

interface Props {
  title: string;
  onPress: () => void;
  variant?: "primary" | "secondary" | "danger" | "ghost";
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
}

export function Button({ title, onPress, variant = "primary", loading, disabled, style }: Props) {
  const bg = {
    primary: Colors.accent.teal,
    secondary: Colors.bg.elevated,
    danger: Colors.accent.coral,
    ghost: "transparent",
  }[variant];

  const textColor = variant === "secondary" || variant === "ghost" ? Colors.text.primary : Colors.text.inverse;

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.base,
        { backgroundColor: bg, opacity: disabled ? 0.5 : pressed ? 0.85 : 1 },
        variant === "ghost" && styles.ghost,
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={textColor} />
      ) : (
        <Text style={[styles.text, { color: textColor }]}>{title}</Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    height: 52,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 20,
  },
  ghost: { borderWidth: 1, borderColor: Colors.border },
  text: { fontSize: 16, fontWeight: "700" },
});
