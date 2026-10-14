import { createClient } from "npm:@supabase/supabase-js@2.105.4";
const hash = async (blob: Blob) => new Uint8Array(await crypto.subtle.digest("SHA-256", await blob.arrayBuffer())).join(",");
Deno.serve(async (request) => {
  const json = (status: number, data: unknown) => new Response(JSON.stringify(data), {
    status, headers: { "Content-Type": "application/json" },
  });
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (request.method !== "POST" || !token)
    return json(403, { error: "Server maintenance only" });
  let phase = "authorize";
  try {
    const input = await request.json();
    // The project's Data API validates the JWT signature and service role.
    // Only service_role has permission to execute this inventory helper.
    const authorized = createClient(Deno.env.get("SUPABASE_URL")!, token, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: files, error } = await authorized.rpc("tokilo_legacy_chat_files");
    if (error || !files) return json(403, { error: "Server maintenance only" });
    const client = authorized;
    if (input.action === "preview") return json(200, { files: files.length });
    if (input.action !== "migrate") return json(400, { error: "Choose preview or migrate" });
    let migrated = 0;
    for (const { path } of files as Array<{ path: string }>) {
      const target = path.slice("chat-attachments/".length);
      if (!/^[0-9a-f-]{36}\/[0-9a-f-]{36}\/[^/]+$/i.test(target)) throw new Error("Invalid legacy path");
      const sourceBucket = client.storage.from("tokilo-media");
      const privateBucket = client.storage.from("chat-attachments");
      phase = "download";
      const { data: source, error: sourceError } = await sourceBucket.download(path);
      if (sourceError || !source) throw sourceError ?? new Error("Source unavailable");
      phase = "copy";
      const { error: uploadError } = await privateBucket.upload(target, source, {
        contentType: source.type, cacheControl: "0", upsert: false,
      });
      phase = "verify";
      const { data: copy, error: copyError } = await privateBucket.download(target);
      if (copyError || !copy || await hash(copy) !== await hash(source)) throw uploadError ?? new Error("Copy verification failed");
      phase = "references";
      const { data: related, error: lookupError } = await client.from("messages").select("id,attachment_path")
        .or(`attachment_path.eq.${path},attachment_url.eq.${sourceBucket.getPublicUrl(path).data.publicUrl}`);
      if (lookupError) throw lookupError;
      if (related?.length) {
        phase = "update";
        const { error: updateError } = await client.from("messages").update({
          attachment_bucket: "chat-attachments", attachment_path: target, attachment_url: null,
        }).in("id", related.map((m) => m.id));
        if (updateError) throw updateError;
      }
      // Keep an identical private copy before removing the public source.
      phase = "remove";
      const { error: removeError } = await sourceBucket.remove([path]);
      if (removeError) throw removeError;
      migrated++;
    }
    return json(200, { success: true, migrated });
  } catch (_) { return json(200, { success: false, phase, error: "Maintenance stopped; verified private copies are retained" }); }
});
