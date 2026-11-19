// UP SKY CMS · gestión del equipo (solo administradores).
//
// Crea la cuenta directamente con una contraseña inicial que elige el administrador, la deja confirmada
// y marca "debe cambiarla" para el primer ingreso. No depende del correo de Supabase.
// El administrador comparte esa contraseña por WhatsApp o como prefiera.
//
// Acciones (POST, JSON):  invite · reset_password · remove
// Despliegue: supabase functions deploy team   (SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY
// los pone la plataforma; no hay que cargar ninguna clave).
//
// Seguridad: la función exige una sesión válida y verifica en la tabla team_members que quien llama sea
// administrador. El límite de 3 personas, el acceso de soporte y "siempre un administrador" los
// vuelve a imponer la base (trigger team_guard); acá se validan antes para dar mensajes claros.

import { createClient } from 'npm:@supabase/supabase-js@2';

const ORIGINS = ['https://upsky-cms.vercel.app', 'http://localhost:5173', 'http://localhost:3000', 'http://localhost:8080'];
const LIMIT = 3;

function corsHeaders(req: Request) {
  const origin = req.headers.get('Origin') ?? '';
  return {
    'Access-Control-Allow-Origin': ORIGINS.includes(origin) ? origin : ORIGINS[0],
    'Vary': 'Origin',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

const json = (req: Request, body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(req), 'Content-Type': 'application/json' } });
const fail = (req: Request, error: string, status = 400) => json(req, { ok: false, error }, status);

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

async function callerEmail(req: Request): Promise<string | null> {
  const anon = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });
  const { data, error } = await anon.auth.getUser();
  if (error || !data?.user?.email) return null;
  return data.user.email.toLowerCase();
}

async function findAuthUser(db: any, email: string) {
  const { data } = await db.auth.admin.listUsers({ page: 1, perPage: 200 });
  return (data?.users ?? []).find((u: any) => (u.email ?? '').toLowerCase() === email) ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'POST') return fail(req, 'Método no permitido', 405);

  const caller = await callerEmail(req);
  if (!caller) return fail(req, 'No autenticado', 401);

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const { data: me } = await db.from('team_members').select('role').eq('email', caller).maybeSingle();
  if (!me || me.role !== 'admin') return fail(req, 'Solo un administrador puede gestionar el equipo.', 403);

  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? '');
  const email = String(body.email ?? '').trim().toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 120) return fail(req, 'Escribí un email válido.');

  const password = typeof body.password === 'string' ? body.password : '';
  const passwordOk = password.length >= 8 && password.length <= 72;

  // ── Invitar ────────────────────────────────────────────────────────────────
  if (action === 'invite') {
    const role = String(body.role ?? '');
    const name = String(body.name ?? '').trim().slice(0, 60);
    if (!['admin', 'editor'].includes(role)) return fail(req, 'Elegí un rol: Administrador o Editor.');

    const { data: already } = await db.from('team_members').select('email').eq('email', email).maybeSingle();
    if (already) return fail(req, 'Esa persona ya está en el equipo.');

    const { count } = await db.from('team_members').select('email', { count: 'exact', head: true }).eq('is_support', false);
    if ((count ?? 0) >= LIMIT) return fail(req, `El equipo ya tiene ${LIMIT} usuarios (el máximo del plan).`);

    const existing = await findAuthUser(db, email);
    let createdId: string | null = null;
    if (!existing) {
      if (!passwordOk) return fail(req, 'La contraseña tiene que tener entre 8 y 72 caracteres.');
      const { data, error } = await db.auth.admin.createUser({
        email, password, email_confirm: true, user_metadata: { name, must_change: true },
      });
      if (error || !data?.user) return fail(req, 'No se pudo crear la cuenta: ' + (error?.message ?? 'error desconocido'));
      createdId = data.user.id;
    }

    const { error: insErr } = await db.from('team_members').insert({ email, role, name: name || null, invited_by: caller });
    if (insErr) {
      if (createdId) await db.auth.admin.deleteUser(createdId); // no dejar una cuenta huérfana
      return fail(req, insErr.message);
    }
    return json(req, { ok: true, existed: !!existing });
  }

  // El resto de las acciones es sobre alguien que ya está en el equipo.
  const { data: target } = await db.from('team_members').select('email, is_support').eq('email', email).maybeSingle();
  if (!target) return fail(req, 'Esa persona no está en el equipo.', 404);
  if (target.is_support) return fail(req, 'El acceso de soporte no se puede modificar desde acá.', 403);

  // ── Nueva contraseña ───────────────────────────────────────────────────────
  if (action === 'reset_password') {
    if (!passwordOk) return fail(req, 'La contraseña tiene que tener entre 8 y 72 caracteres.');
    const user = await findAuthUser(db, email);
    if (!user) return fail(req, 'No se encontró la cuenta de esa persona.', 404);
    const { error } = await db.auth.admin.updateUserById(user.id, {
      password, user_metadata: { ...(user.user_metadata ?? {}), must_change: true },
    });
    if (error) return fail(req, 'No se pudo cambiar la contraseña: ' + error.message);
    return json(req, { ok: true });
  }

  // ── Quitar del equipo ──────────────────────────────────────────────────────
  if (action === 'remove') {
    if (email === caller) return fail(req, 'No podés quitarte a vos mismo del equipo.');
    const { error } = await db.from('team_members').delete().eq('email', email);
    if (error) return fail(req, error.message);
    const user = await findAuthUser(db, email);
    if (user) await db.auth.admin.deleteUser(user.id);
    return json(req, { ok: true });
  }

  return fail(req, 'Acción desconocida.');
});
