import { useCallback, useEffect, useState } from "react";

import { api } from "@/lib/api";
import { getObject, setObject, tokenStore } from "@/lib/storage";

export interface ChatMessage {
  id: string;
  role: "user" | "assistant";
  text: string;
  at: string;
}

const STORAGE_KEY = "coach_conversation";

export function useCoach(userName: string) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [conversationId, setConversationId] = useState<string | undefined>();
  const [streaming, setStreaming] = useState(false);

  useEffect(() => {
    (async () => {
      const saved = await getObject<{ messages: ChatMessage[]; conversationId?: string }>(STORAGE_KEY);
      if (saved?.messages?.length) {
        setMessages(saved.messages);
        setConversationId(saved.conversationId);
      } else {
        setMessages([
          {
            id: "welcome",
            role: "assistant",
            text: `Hi ${userName}! I'm your AllergyDetect coach. Ask me about your allergens, macros, or recent reactions.`,
            at: new Date().toISOString(),
          },
        ]);
      }
    })();
  }, [userName]);

  const persist = useCallback(
    (msgs: ChatMessage[], convId?: string) => {
      void setObject(STORAGE_KEY, { messages: msgs, conversationId: convId });
    },
    []
  );

  const send = useCallback(
    async (text: string) => {
      const userMsg: ChatMessage = { id: `u${Date.now()}`, role: "user", text, at: new Date().toISOString() };
      const assistantMsg: ChatMessage = { id: `a${Date.now()}`, role: "assistant", text: "", at: new Date().toISOString() };
      setMessages((m) => [...m, userMsg, assistantMsg]);
      setStreaming(true);

      try {
        const token = await tokenStore.getAccess();
        const res = await fetch(api.coachChatUrl(), {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
          body: JSON.stringify({ message: text, conversation_id: conversationId }),
        });

        const reader = res.body?.getReader();
        if (!reader) {
          throw new Error("No stream");
        }
        const decoder = new TextDecoder();
        let buffer = "";
        let accumulated = "";
        let convId = conversationId;

        // eslint-disable-next-line no-constant-condition
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n\n");
          buffer = lines.pop() ?? "";
          for (const line of lines) {
            const payload = line.replace(/^data: /, "").trim();
            if (!payload) continue;
            const evt = JSON.parse(payload) as { type: string; text?: string; conversation_id?: string };
            if (evt.type === "meta" && evt.conversation_id) {
              convId = evt.conversation_id;
              setConversationId(convId);
            } else if (evt.type === "chunk" && evt.text) {
              accumulated += evt.text;
              setMessages((m) =>
                m.map((msg) => (msg.id === assistantMsg.id ? { ...msg, text: accumulated } : msg))
              );
            }
          }
        }
        setMessages((m) => {
          const next = m.map((msg) => (msg.id === assistantMsg.id ? { ...msg, text: accumulated } : msg));
          persist(next, convId);
          return next;
        });
      } catch {
        setMessages((m) =>
          m.map((msg) =>
            msg.id === assistantMsg.id
              ? { ...msg, text: "Sorry, I couldn't reach the coach service. Please try again." }
              : msg
          )
        );
      } finally {
        setStreaming(false);
      }
    },
    [conversationId, persist]
  );

  const reset = useCallback(() => {
    setMessages([]);
    setConversationId(undefined);
    void setObject(STORAGE_KEY, { messages: [] });
  }, []);

  return { messages, send, streaming, reset };
}
