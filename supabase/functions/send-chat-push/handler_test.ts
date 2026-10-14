import { assertEquals } from "jsr:@std/assert@1";
import { createPushHandler } from "./handler.ts";
const id = "10000000-0000-4000-8000-000000000001";
const req = () => new Request("https://function.test", { method: "POST", headers: {
  authorization: "Bearer test-token", "Content-Type": "application/json" }, body: JSON.stringify({ message_id: id }) });
Deno.test("non-admin cannot look up messages or send notifications", async () => {
  let lookedUp = false;
  const handler = createPushHandler({ authenticate: async () => ({ id: "client", email: "client@example.test" }),
    message: async () => { lookedUp = true; return null; }, send: async () => { throw new Error("Must not send"); } });
  assertEquals((await handler(req())).status, 403);
  assertEquals(lookedUp, false);
});
Deno.test("admin cannot push another sender's message", async () => {
  const handler = createPushHandler({ authenticate: async () => ({ id: "admin", email: "mubassirnasar@gmail.com" }),
    message: async () => ({ id, sender_id: "other", sender_role: "admin", recipient_id: "client", conversation_id: id }),
    send: async () => { throw new Error("Must not send"); } });
  assertEquals((await handler(req())).status, 404);
});
Deno.test("unauthenticated requests never disclose metadata", async () => {
  const handler = createPushHandler({ authenticate: async () => null, message: async () => { throw new Error("Must not query"); }, send: async () => 0 });
  assertEquals((await handler(req())).status, 401);
});
Deno.test("successful push returns only delivery count", async () => {
  const handler = createPushHandler({ authenticate: async () => ({ id: "admin", email: "mubassirnasar@gmail.com" }),
    message: async () => ({ id, sender_id: "admin", sender_role: "admin", recipient_id: "client", conversation_id: id }), send: async () => 1 });
  assertEquals(await (await handler(req())).json(), { success: true, sent: 1 });
});
