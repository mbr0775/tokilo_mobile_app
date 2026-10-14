type User = { id: string; email?: string };
export type DeletionDependencies = {
  authenticate: (token: string) => Promise<User | null>;
  files: (userId: string) => Promise<Array<{ bucket_id: string; path: string }>>;
  removeFiles: (bucket: string, paths: string[]) => Promise<void>;
  removeData: (userId: string) => Promise<void>;
  removeUser: (userId: string) => Promise<void>;
};
const cors = { "Access-Control-Allow-Origin": "https://www.tokilotech.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS", "Cache-Control": "no-store" };

export function deletionHandler(dependencies: DeletionDependencies) {
  return async (request: Request): Promise<Response> => {
    const reply = (status: number, data: unknown) => Response.json(data, { status, headers: cors });
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (request.method !== "POST") return reply(405, { error: "Use POST." });
    const token = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) return reply(401, { error: "Sign in to delete your account." });
    try {
      const user = await dependencies.authenticate(token);
      if (!user) return reply(401, { error: "Please sign in again." });
      // Company assets need a verified handover, not removal with a personal account.
      if (user.email?.toLowerCase() === "mubassirnasar@gmail.com") {
        return reply(409, { error: "Request administrator account deletion through Tokilo support.", code: "support_required" });
      }
      let confirmation: unknown;
      try { confirmation = (await request.json()).confirmation; } catch { /* invalid body */ }
      if (confirmation !== "DELETE") return reply(400, { error: "Confirm account deletion first." });
      // The target always comes from the verified token, never a request user_id.
      const files = await dependencies.files(user.id);
      const buckets = new Map<string, string[]>();
      for (const file of files) {
        const paths = buckets.get(file.bucket_id) ?? [];
        paths.push(file.path); buckets.set(file.bucket_id, paths);
      }
      for (const [bucket, paths] of buckets) {
        for (let offset = 0; offset < paths.length; offset += 100) {
          await dependencies.removeFiles(bucket, paths.slice(offset, offset + 100));
        }
      }
      await dependencies.removeData(user.id);
      await dependencies.removeUser(user.id);
      return reply(200, { success: true, deleted_user_id: user.id });
    } catch {
      return reply(500, { error: "Account deletion could not complete. Please retry or contact Tokilo support." });
    }
  };
}
