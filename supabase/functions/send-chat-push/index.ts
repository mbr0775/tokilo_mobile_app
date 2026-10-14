import { createClient } from "npm:@supabase/supabase-js@2.105.4";
import { JWT } from "npm:google-auth-library@9";
import { createPushHandler } from "./handler.ts";
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
Deno.serve(createPushHandler({
  async authenticate(token) {
    const { data, error } = await supabase.auth.getUser(token);
    return error || !data.user ? null : { id: data.user.id, email: data.user.email ?? "" };
  },
  async message(id) {
    const { data, error } = await supabase.from("messages").select(
      "id,sender_id,sender_role,conversation_id,conversations(client_id)",
    ).eq("id", id).maybeSingle();
    if (error || !data) return null;
    const conversation = Array.isArray(data.conversations) ? data.conversations[0] : data.conversations;
    return { ...data, recipient_id: conversation?.client_id ?? "" };
  },
  async send(message) {
    const { data, error } = await supabase.from("user_push_tokens").select("token").eq("user_id", message.recipient_id);
    if (error) throw error;
    if (!data?.length) return 0;
    const account = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
    if (account.project_id !== "tokilomobileapp") throw new Error("Firebase project mismatch");
    const jwt = new JWT({ email: account.client_email, key: account.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"] });
    const auth = await jwt.authorize();
    let sent = 0;
    for (const row of data) {
      const result = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
        method: "POST", signal: AbortSignal.timeout(10000),
        headers: { Authorization: `Bearer ${auth.access_token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ message: {
          token: row.token,
          notification: { title: "Tokilo Support", body: "You have a new support message." },
          data: { type: "chat", conversation_id: message.conversation_id,
            message_id: message.id, recipient_id: message.recipient_id },
          android: { priority: "HIGH", notification: { channel_id: "tokilo_chat_channel",
            icon: "ic_stat_tokilo", visibility: "PRIVATE", tag: message.id } },
        } }),
      });
      if (result.ok) sent++;
      await result.body?.cancel();
    }
    return sent;
  },
}));
