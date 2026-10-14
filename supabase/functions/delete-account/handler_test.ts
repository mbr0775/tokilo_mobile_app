import { deletionHandler, type DeletionDependencies } from "./handler.ts";

function assert(condition: unknown, message: string) { if (!condition) throw new Error(message); }
function fixture(overrides: Partial<DeletionDependencies> = {}) {
  const calls: string[] = [];
  const dependencies: DeletionDependencies = {
    authenticate: async token => token === "valid" ? { id: "own-user", email: "qa@example.invalid" } : null,
    files: async id => { calls.push(`files:${id}`); return [{ bucket_id: "chat-attachments", path: "own/image.png" }]; },
    removeFiles: async bucket => { calls.push(`storage:${bucket}`); },
    removeData: async id => { calls.push(`data:${id}`); },
    removeUser: async id => { calls.push(`user:${id}`); },
    ...overrides,
  };
  return { calls, handler: deletionHandler(dependencies) };
}
function request(token?: string, body: unknown = { confirmation: "DELETE" }) {
  return new Request("https://fixture.test/delete-account", { method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {}, body: JSON.stringify(body) });
}
Deno.test("deletion rejects missing or invalid authentication before accessing data", async () => {
  const { handler, calls } = fixture();
  assert((await handler(request())).status === 401, "Missing auth must fail");
  assert((await handler(request("invalid"))).status === 401, "Invalid auth must fail");
  assert(calls.length === 0, "Must not access account data");
});
Deno.test("deletion requires confirmation and rejects GET", async () => {
  const { handler, calls } = fixture();
  assert((await handler(request("valid", {}))).status === 400, "Missing confirmation must fail");
  assert((await handler(new Request("https://fixture.test"))).status === 405, "GET must fail");
  assert(calls.length === 0, "Must not delete before confirmation");
});
Deno.test("a forged target cannot delete another account", async () => {
  const { handler, calls } = fixture();
  const response = await handler(request("valid", { confirmation: "DELETE", user_id: "other-user" }));
  assert(response.status === 200, "Own account should delete");
  assert(calls.join(",") === "files:own-user,storage:chat-attachments,data:own-user,user:own-user", "Only verified principal can be targeted");
});
Deno.test("storage failure cannot report a deleted account or proceed to delete the user", async () => {
  const { handler, calls } = fixture({ removeFiles: async () => { throw new Error("storage failed"); } });
  const response = await handler(request("valid"));
  assert(response.status === 500, "Storage failure must fail closed");
  assert(!calls.some(call => call.startsWith("data:") || call.startsWith("user:")), "Do not delete user after failed storage cleanup");
});
Deno.test("database cleanup failure cannot proceed to auth deletion", async () => {
  const { handler, calls } = fixture({ removeData: async () => { throw new Error("db failed"); } });
  assert((await handler(request("valid"))).status === 500, "Database failure must fail closed");
  assert(!calls.some(call => call.startsWith("user:")), "Do not orphan associated data");
});
Deno.test("company administrator gets the verified support path without losing assets", async () => {
  const { handler, calls } = fixture({ authenticate: async () => ({ id: "admin", email: "mubassirnasar@gmail.com" }) });
  assert((await handler(request("valid"))).status === 409, "Admin needs verified handover");
  assert(calls.length === 0, "Company assets must remain intact");
});
