export type PushMessage = { id: string; sender_id: string; sender_role: string; conversation_id: string; recipient_id: string };
type Dependencies = {
  authenticate(token: string): Promise<{ id: string; email: string } | null>;
  message(id: string): Promise<PushMessage | null>;
  send(message: PushMessage): Promise<number>;
};
export function createPushHandler(deps: Dependencies) {
  const headers = { "Content-Type": "application/json", "Access-Control-Allow-Origin": "https://www.tokilotech.com",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
  const response = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers });
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (request.method !== "POST") return response(405, { error: "Method not allowed" });
    try {
      const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
      const caller = token ? await deps.authenticate(token) : null;
      if (!caller) return response(401, { error: "Sign in required" });
      if (caller.email.toLowerCase() !== "mubassirnasar@gmail.com") return response(403, { error: "Support only" });
      const { message_id } = await request.json();
      if (typeof message_id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(message_id))
        return response(400, { error: "Invalid message" });
      const message = await deps.message(message_id);
      if (!message || message.sender_id !== caller.id || message.sender_role !== "admin" || !message.recipient_id)
        return response(404, { error: "Message unavailable" });
      const sent = await deps.send(message);
      return response(200, { success: true, sent });
    } catch (_) { return response(500, { error: "Push delivery could not complete" }); }
  };
}
