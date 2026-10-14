// Production mutation: run only with explicit owner approval for a disposable account.
// Keys and account passwords are never printed or written into the repository.
import { createClient } from "npm:@supabase/supabase-js@2.105.4";
if (!Deno.args.includes("--confirm-disposable-deletion")) {
  throw new Error("Owner approval required; pass --confirm-disposable-deletion only after approval.");
}
const keyIndex = Deno.args.indexOf("--service-key-file");
if (keyIndex < 0) throw new Error("Provide the private temporary service key file.");
const key = (await Deno.readTextFile(Deno.args[keyIndex + 1])).trim();
const claims = JSON.parse(atob(key.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
if (claims.ref !== "nsosypdtxdoeiszilpwj" || claims.role !== "service_role") throw new Error("Incorrect project/role.");
const source = await Deno.readTextFile("lib/core/constants/supabase_constants.dart");
const anon = source.match(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/)?.[0];
if (!anon) throw new Error("App public key missing.");
const url = "https://nsosypdtxdoeiszilpwj.supabase.co";
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(url, key, options);
const client = createClient(url, anon, options);
const nonce = crypto.randomUUID();
const email = `release-delete-${nonce}@example.test`;
const password = `${crypto.randomUUID()}A!7`;
let userId: string | undefined;
let filePath: string | undefined;
let phase = "create";
const checked = <R extends { data: unknown; error: unknown }>(result: R): R["data"] => {
  if (result.error) throw new Error(`Operation failed during ${phase}`);
  return result.data;
};
try {
  const creation = checked(await admin.auth.admin.createUser({ email, password, email_confirm: true,
    user_metadata: { full_name: "Disposable release deletion fixture", release_test: nonce } }));
  userId = creation.user!.id;
  phase = "sign-in";
  const login = checked(await client.auth.signInWithPassword({ email, password }));
  const token = login.session!.access_token;
  phase = "seed-request";
  checked(await client.from("client_projects").insert({ client_id: userId, client_email: email,
    client_name: "Disposable release fixture", request_type: "software", title: "Deletion fixture",
    description: "Owner-approved disposable test record", status: "pending", progress: 0 }));
  phase = "seed-private-file";
  // Orphan upload coverage: account cleanup must find owned files even without a message.
  filePath = `${userId}/${crypto.randomUUID()}/deletion-fixture.png`;
  const png = Uint8Array.from(atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2ioAAAAASUVORK5CYII="), (c) => c.charCodeAt(0));
  checked(await admin.storage.from("chat-attachments").upload(filePath, png, { contentType: "image/png", upsert: false }));
  phase = "delete-endpoint";
  const response = await fetch(`${url}/functions/v1/delete-account`, { method: "POST",
    headers: { apikey: anon, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ confirmation: "DELETE" }), signal: AbortSignal.timeout(35000) });
  const result = await response.json();
  if (!response.ok || result.success !== true || result.deleted_user_id !== userId) {
    throw new Error(`Deletion endpoint failed: HTTP ${response.status}`);
  }
  phase = "verify";
  const authUser = await admin.auth.admin.getUserById(userId);
  if (authUser.data.user) throw new Error("Deleted Auth account still exists.");
  for (const [table, column] of [["client_projects", "client_id"], ["users", "id"], ["profiles", "id"]]) {
    const data = checked(await admin.from(table).select(column).eq(column, userId));
    if (!data || data.length) throw new Error(`Deleted records remain in ${table}`);
  }
  const inventory = checked(await admin.rpc("tokilo_account_deletion_files", { p_user_id: userId }));
  if (inventory.length) throw new Error("Deleted account storage remains.");
  const oldTokenRequest = await client.from("client_projects").insert({ client_id: userId, client_email: email,
    client_name: "Deleted fixture", request_type: "software", title: "Stale token fixture", description: "Must be rejected", status: "pending", progress: 0 });
  if (!oldTokenRequest.error) throw new Error("Deleted account's old token could recreate a request.");
  console.log(JSON.stringify({ success: true, account_deleted: true, request_records_removed: true,
    private_orphan_upload_removed: true, old_token_request_blocked: true }));
} catch (error) {
  console.error(JSON.stringify({ success: false, phase,
    error: error instanceof Error ? error.message : "Test failed" }));
  Deno.exitCode = 1;
} finally {
  // Cleanup only the uniquely identified owner-approved disposable fixture.
  if (userId) {
    if (filePath) await admin.storage.from("chat-attachments").remove([filePath]);
    await admin.rpc("tokilo_delete_account_data", { p_user_id: userId });
    await admin.auth.admin.deleteUser(userId);
  }
  await Deno.remove(Deno.args[keyIndex + 1]);
}
