// Migration completed and verified on 2026-10-14. The maintenance endpoint is disabled.
Deno.serve(() => Response.json({ error: "Maintenance endpoint disabled" }, { status: 403 }));
