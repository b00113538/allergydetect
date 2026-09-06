import { ReactNode } from "react";
import { Pressable, StyleSheet, View, ViewStyle } from "react-native";

import { Colors } from "@/constants/colors";

interface Props {
  children: ReactNode;
  onPress?: () => void;
  style?: ViewStyle;
  elevated?: boolean;
}

export function Card({ children, onPress, style, elevated }: Props) {
  const content = (
    <View style={[styles.card, elevated && styles.elevated, style]}>{children}</View>
  );
  if (onPress) {
    return (
      <Pressable onPress={onPress} style={({ pressed }) => ({ opacity: pressed ? 0.9 : 1 })}>
        {content}
      </Pressable>
    );
  }
  return content;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.bg.card,
    borderRadius: 18,
    padding: 16,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  elevated: { backgroundColor: Colors.bg.elevated },
});
