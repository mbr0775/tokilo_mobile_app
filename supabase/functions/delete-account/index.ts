import { createClient } from "npm:@supabase/supabase-js@2.105.4";
import { deletionHandler } from "./handler.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } });
Deno.serve(deletionHandler({
  async authenticate(token) {
    const { data, error } = await admin.auth.getUser(token);
    return error ? null : data.user;
  },
  async files(userId) {
    const { data, error } = await admin.rpc("tokilo_account_deletion_files", { p_user_id: userId });
    if (error) throw error;
    return data ?? [];
  },
  async removeFiles(bucket, paths) {
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) throw error;
  },
  async removeData(userId) {
    const { error } = await admin.rpc("tokilo_delete_account_data", { p_user_id: userId });
    if (error) throw error;
  },
  async removeUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
}));
