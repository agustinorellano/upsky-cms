// UP SKY CMS · notificaciones push.
//
// Acciones (POST, JSON):
//   key    (sesión del equipo)  devuelve la clave pública para suscribirse. La primera vez genera las claves VAPID
//                               y las guarda en push_config (tabla privada: nunca se muestran ni se piden por chat).
//   test   (sesión del equipo)  manda una notificación de prueba a los dispositivos de quien llama.
//   event  (secreto interno)    clic a WhatsApp o producto agregado al carrito. Lo dispara la base de datos.
//   agenda (secreto interno)    evento de mañana, promoción que termina en 24 h, publicación que salió. Lo dispara pg_cron.
//
// Seguridad: "key" y "test" exigen una sesión válida de alguien del equipo (administrador o editor).
// "event" y "agenda" exigen el secreto de push_config en el encabezado x-push-secret (lo conocen solo la base y esta función).
// Despliegue: supabase functions deploy push --no-verify-jwt   (SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY los pone la plataforma).

import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const ORIGINS = ['https://upsky-cms.vercel.app', 'http://localhost:5173', 'http://localhost:3000', 'http://localhost:8080'];
const SUBJECT = 'mailto:soporte@conectado.com';
const TZ_OFFSET_H = -3; // Argentina

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

async function callerEmail(req: Request): Promise<string | null> {
  const anon = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });
  const { data, error } = await anon.auth.getUser();
  if (error || !data?.user?.email) return null;
  return data.user.email.toLowerCase();
}

const same = (a: string, b: string) => {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
};

type Msg = { title: string; body: string; tag: string; url?: string };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'POST') return fail(req, 'Método no permitido', 405);

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? '');

  // Configuración (y claves VAPID: se generan una sola vez)
  let { data: cfg } = await db.from('push_config').select('vapid_public, vapid_private, secret').eq('id', 1).maybeSingle();
  if (!cfg) return fail(req, 'Falta la configuración de notificaciones.', 500);

  async function ensureKeys() {
    if (cfg!.vapid_public && cfg!.vapid_private) return;
    const k = webpush.generateVAPIDKeys();
    // solo se guardan si todavía no hay (evita pisar claves ante dos pedidos a la vez)
    await db.from('push_config').update({ vapid_public: k.publicKey, vapid_private: k.privateKey }).eq('id', 1).is('vapid_public', null);
    ({ data: cfg } = await db.from('push_config').select('vapid_public, vapid_private, secret').eq('id', 1).maybeSingle());
  }

  async function send(subs: any[], msg: Msg) {
    await ensureKeys();
    const opts = { vapidDetails: { subject: SUBJECT, publicKey: cfg!.vapid_public!, privateKey: cfg!.vapid_private! }, TTL: 3600 };
    const payload = JSON.stringify({ title: msg.title, body: msg.body, tag: msg.tag, url: msg.url ?? '/' });
    let sent = 0;
    for (const s of subs) {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, opts);
        sent++;
      } catch (e: any) {
        // 404/410: el dispositivo ya no existe → se borra para no insistir
        if (e?.statusCode === 404 || e?.statusCode === 410) await db.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
      }
    }
    return sent;
  }
  const subsFor = async (pref: string) => {
    const { data } = await db.from('push_subscriptions').select('endpoint, p256dh, auth, prefs, email');
    return (data ?? []).filter((s: any) => (s.prefs ?? {})[pref] !== false);
  };

  // ── Acciones internas (base de datos y cron) ─────────────────────────────────
  if (action === 'event' || action === 'agenda') {
    const given = req.headers.get('x-push-secret') ?? '';
    if (!given || !same(given, cfg.secret)) return fail(req, 'No autorizado', 401);

    if (action === 'event') {
      const kind = String(body.kind ?? '');
      const target = String(body.target ?? '').slice(0, 80);
      const msg: Msg | null = kind === 'whatsapp'
        ? { title: 'Alguien quiere comprar', body: 'Hicieron clic para escribirte por WhatsApp desde la web.', tag: 'whatsapp' }
        : kind === 'cart'
        ? { title: 'Nuevo producto en un carrito', body: target ? `Agregaron “${target}” al carrito.` : 'Agregaron un producto al carrito.', tag: 'cart' }
        : null;
      if (!msg) return fail(req, 'Tipo desconocido.');
      return json(req, { ok: true, sent: await send(await subsFor(kind), msg) });
    }

    // agenda
    const now = Date.now();
    const local = new Date(now + TZ_OFFSET_H * 3600e3);
    const tomorrow = new Date(local.getTime() + 864e5).toISOString().slice(0, 10);
    const { data: rows } = await db.from('items').select('id, section, active, data').eq('active', true).in('section', ['eventos', 'promos', 'productos', 'comunidad', 'sitio']);
    const todo: { key: string; msg: Msg }[] = [];
    for (const r of rows ?? []) {
      const d = r.data ?? {};
      const name = String(d.nombre ?? d.titulo ?? 'Sin nombre').slice(0, 60);
      if (r.section === 'eventos' && d.fecha === tomorrow) {
        todo.push({ key: `evento:${r.id}:${d.fecha}`, msg: { title: 'Evento mañana', body: `${name}${d.hora ? ' · ' + d.hora + ' h' : ''}${d.lugar ? ' · ' + d.lugar : ''}`, tag: 'agenda' } });
      }
      const fin = Date.parse(d.ocultar_desde ?? '');
      if (r.section === 'promos' && fin > now && fin - now <= 24 * 3600e3) {
        todo.push({ key: `promo-fin:${r.id}:${d.ocultar_desde}`, msg: { title: 'Una promoción termina pronto', body: `“${name}” termina en menos de 24 horas.`, tag: 'agenda' } });
      }
      const ini = Date.parse(d.publicar_desde ?? '');
      if (ini <= now && now - ini <= 70 * 60e3 && ini > 0) {
        todo.push({ key: `publicado:${r.id}:${d.publicar_desde}`, msg: { title: 'Se publicó contenido programado', body: `“${name}” ya se ve en la web.`, tag: 'agenda' } });
      }
    }
    let sent = 0, fresh = 0;
    const subs = await subsFor('agenda');
    for (const t of todo) {
      const { data: ins } = await db.from('push_log').insert({ key: t.key, kind: 'agenda' }).select('key');
      if (!ins || !ins.length) continue; // ya se avisó
      fresh++;
      sent += await send(subs, t.msg);
    }
    return json(req, { ok: true, items: fresh, sent });
  }

  // ── Acciones del equipo ──────────────────────────────────────────────────────
  const caller = await callerEmail(req);
  if (!caller) return fail(req, 'No autenticado', 401);
  const { data: me } = await db.from('team_members').select('role').eq('email', caller).maybeSingle();
  if (!me || !['admin', 'editor'].includes(me.role)) return fail(req, 'No tenés acceso al panel.', 403);

  if (action === 'key') {
    await ensureKeys();
    return json(req, { ok: true, key: cfg.vapid_public });
  }
  if (action === 'test') {
    const { data } = await db.from('push_subscriptions').select('endpoint, p256dh, auth').eq('email', caller);
    if (!data || !data.length) return fail(req, 'Este dispositivo todavía no tiene las notificaciones activadas.');
    const sent = await send(data, { title: 'Notificaciones activas', body: 'Así te vamos a avisar de lo que pase en tu sitio.', tag: 'test' });
    return json(req, { ok: true, sent });
  }
  return fail(req, 'Acción desconocida.');
});
