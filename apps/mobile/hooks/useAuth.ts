import { useAuthStore } from "@/store/auth";

export function useAuth() {
  return useAuthStore();
}
