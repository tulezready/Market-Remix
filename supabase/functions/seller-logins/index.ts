// seller-logins — lets Division staff create and manage seller logins from the
// Division panel, without the secret key ever reaching a browser.
//
// POST JSON { action, ... } with the signed-in staff member's session token:
//   list                          → [{ sme_id, email, last_sign_in_at }]
//   create { sme_id, login, name } → links a login to the business; creates it
//                                    if new and returns a temporary password
//   reset  { sme_id }             → new temporary password for the business login
//   remove { sme_id }             → unlinks the login from the business
//
// A login is an email address, or a PNG mobile number, which is stored as
// <digits>@phone.maketples.com.pg until SMS sign-in is available.
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SECRET = (() => {
  try { return JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}").default; } catch { return undefined; }
})() ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(URL, SECRET, { auth: { persistSession: false, autoRefreshToken: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const fail = (message: string, status = 400) => reply({ error: message }, status);

const PHONE_DOMAIN = "phone.maketples.com.pg";
function toLogin(raw: string): string | null {
  const s = (raw ?? "").trim().toLowerCase();
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s)) return s;
  let d = s.replace(/[^\d]/g, "");
  if (d.length === 8 && d.startsWith("7")) d = "675" + d;      // 7XXX XXXX → +675
  if (/^6757\d{7}$/.test(d)) return `${d}@${PHONE_DOMAIN}`;
  return null;
}
function tempPassword(): string {
  const a = "abcdefghjkmnpqrstuvwxyz23456789";
  const b = crypto.getRandomValues(new Uint8Array(12));
  const c = [...b].map((n) => a[n % a.length]).join("");
  return `${c.slice(0, 4)}-${c.slice(4, 8)}-${c.slice(8)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail("Use POST.", 405);

  // who is calling? must be signed-in Division staff
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return fail("Please sign in.", 401);
  const { data: who, error: whoErr } = await admin.auth.getUser(token);
  if (whoErr || !who?.user) return fail("Your session has expired. Please sign in again.", 401);
  const { data: me } = await admin.from("profiles").select("role").eq("id", who.user.id).single();
  if (!me || !["division_staff", "division_admin"].includes(me.role)) return fail("Division staff only.", 403);

  let body: Record<string, string>;
  try { body = await req.json(); } catch { return fail("Bad request."); }

  if (body.action === "list") {
    const { data, error } = await admin.rpc("seller_logins");
    if (error) return fail(error.message, 500);
    return reply({ logins: data });
  }

  const smeId = body.sme_id;
  if (!smeId) return fail("Which business?");
  const { data: sme } = await admin.from("smes").select("id, owner_id, registered_name").eq("id", smeId).single();
  if (!sme) return fail("Business not found.", 404);

  if (body.action === "create") {
    const login = toLogin(body.login);
    if (!login) return fail("Enter an email address or a PNG mobile number (7XXX XXXX).");
    if (sme.owner_id) return fail("This business already has a login. Remove it first to link a different one.");

    let userId: string;
    let password: string | null = null;
    const { data: found } = await admin.rpc("auth_user_by_email", { p_email: login });
    if (found && found.length) {
      userId = found[0].id;                       // an existing login: link it, keep its password
    } else {
      password = tempPassword();
      const { data: created, error } = await admin.auth.admin.createUser({
        email: login, password, email_confirm: true,
        user_metadata: { full_name: body.name || sme.registered_name, must_change_password: true },
      });
      if (error || !created.user) return fail(error?.message ?? "Could not create the login.", 500);
      userId = created.user.id;
    }

    const { error: e1 } = await admin.from("smes").update({ owner_id: userId }).eq("id", smeId);
    if (e1) return fail(e1.message, 500);
    // sellers only; never demote Division staff who also run a business
    await admin.from("profiles").update({ role: "seller" }).eq("id", userId).in("role", ["buyer"]);
    return reply({ login, password, existing: password === null });
  }

  if (body.action === "reset") {
    if (!sme.owner_id) return fail("This business has no login yet.");
    const password = tempPassword();
    const { data: u } = await admin.auth.admin.getUserById(sme.owner_id);
    const { error } = await admin.auth.admin.updateUserById(sme.owner_id, {
      password,
      user_metadata: { ...(u?.user?.user_metadata ?? {}), must_change_password: true },
    });
    if (error) return fail(error.message, 500);
    return reply({ login: u?.user?.email, password });
  }

  if (body.action === "remove") {
    const { error } = await admin.from("smes").update({ owner_id: null }).eq("id", smeId);
    if (error) return fail(error.message, 500);
    return reply({ removed: true });
  }

  return fail("Unknown action.");
});
