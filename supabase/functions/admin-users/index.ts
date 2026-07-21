// ATLAS admin-users Edge Function.
// Server-side replacement for the old client-direct writes to tqs_users
// (createNewUser/deleteUser/toggleUserActivo). Verifies the caller's JWT,
// confirms rol='admin' via a service_role read, then uses service_role to
// touch auth.users + public.tqs_users together so they never drift.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace("Bearer ", "");
  if (!jwt) return json({ error: "missing token" }, 401);

  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await callerClient.auth.getUser(jwt);
  if (userErr || !user) return json({ error: "invalid session" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: callerProfile, error: profileErr } = await admin
    .from("tqs_users")
    .select("rol")
    .eq("id", user.id)
    .single();
  if (profileErr || callerProfile?.rol !== "admin") {
    return json({ error: "forbidden: admin only" }, 403);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid json body" }, 400);
  }
  const { action } = payload;

  if (action === "create") {
    const { email, password, nombre, rol, sistemas } = payload as {
      email?: string; password?: string; nombre?: string; rol?: string; sistemas?: string[];
    };
    if (!email || !password || !nombre || !rol) {
      return json({ error: "email, password, nombre, rol required" }, 400);
    }
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nombre, rol },
    });
    if (createErr || !created.user) return json({ error: createErr?.message ?? "createUser failed" }, 400);

    const { error: insertErr } = await admin.from("tqs_users").insert({
      id: created.user.id,
      email,
      nombre,
      rol,
      sistemas: sistemas ?? [],
      primer_login: true,
      activo: true,
    });
    if (insertErr) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: insertErr.message }, 400);
    }
    return json({ ok: true, id: created.user.id });
  }

  if (action === "delete") {
    const { id } = payload as { id?: string };
    if (!id) return json({ error: "id required" }, 400);
    if (id === user.id) return json({ error: "cannot delete your own account" }, 400);

    await admin.from("rfcs").delete().eq("owner_id", id);
    await admin.from("solicitudes").delete().eq("owner_id", id);
    await admin.from("tqs_users").delete().eq("id", id);
    const { error: delErr } = await admin.auth.admin.deleteUser(id);
    if (delErr) return json({ error: delErr.message }, 400);
    return json({ ok: true });
  }

  if (action === "toggleActivo") {
    const { id, activo } = payload as { id?: string; activo?: boolean };
    if (!id || typeof activo !== "boolean") return json({ error: "id, activo required" }, 400);

    const { error: updErr } = await admin.from("tqs_users").update({ activo }).eq("id", id);
    if (updErr) return json({ error: updErr.message }, 400);

    // Mirror into auth so a deactivated account can't sign in even with a valid password.
    const { error: banErr } = await admin.auth.admin.updateUserById(id, {
      ban_duration: activo ? "none" : "87600h",
    });
    if (banErr) return json({ error: banErr.message }, 400);
    return json({ ok: true });
  }

  return json({ error: "unknown action" }, 400);
});
