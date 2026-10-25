// Crea un usuario Express de pasajero, conductor o restaurante.
// Las claves de servicio solo se usan en esta función; el panel nunca las recibe.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function respond(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function temporaryPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
  const random = new Uint32Array(24);
  crypto.getRandomValues(random);
  return Array.from(random, value => chars[value % chars.length]).join('');
}

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return respond({ error: 'Método no permitido.' }, 405);

  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization) return respond({ error: 'Inicia sesión como administrador.' }, 401);

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const token = authorization.replace(/^Bearer\s+/i, '').trim();
  const { data: identity, error: identityError } = await caller.auth.getUser(token);
  if (identityError || !identity.user) return respond({ error: 'Sesión vencida.' }, 401);
  const { data: adminContext, error: adminError } = await caller.rpc('admin_access_context');
  if (adminError || adminContext?.allowed !== true || adminContext?.role !== 'super_admin') {
    return respond({ error: 'Solo el administrador principal puede crear cuentas.' }, 403);
  }

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return respond({ error: 'Datos inválidos.' }, 400); }
  const email = String(body.email ?? '').trim().toLowerCase();
  const fullName = String(body.full_name ?? '').trim();
  const accountType = String(body.account_type ?? '').trim();
  const channel = String(body.channel ?? '').trim();
  const zoneId = String(body.zone_id ?? '').trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return respond({ error: 'Correo no válido.' }, 400);
  if (fullName.length < 2 || fullName.length > 120) return respond({ error: 'Escribe el nombre completo.' }, 400);
  if (!['passenger', 'driver', 'restaurant'].includes(accountType)) return respond({ error: 'Tipo de cuenta inválido.' }, 400);
  if (!['preview', 'production'].includes(channel)) return respond({ error: 'Entorno inválido.' }, 400);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(zoneId)) return respond({ error: 'Selecciona una zona activa.' }, 400);

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: zone, error: zoneError } = await admin.from('service_zones')
    .select('id,active,name,country_code').eq('id', zoneId).maybeSingle();
  if (zoneError || zone?.active !== true) return respond({ error: 'La zona no está activa.' }, 400);

  const password = temporaryPassword();
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, express_account_type: accountType },
  });
  if (createError || !created.user) return respond({ error: createError?.message ?? 'No se pudo crear la cuenta.' }, 400);

  const userId = created.user.id;
  const rollback = async (message: string) => {
    const { error } = await admin.auth.admin.deleteUser(userId);
    return respond({ error: error ? `${message} La cuenta requiere revisión manual.` : message }, 422);
  };

  const { error: profileError } = await admin.from('users').upsert({
    id: userId,
    full_name: fullName,
    active_mode: accountType === 'driver' ? 'driver' : 'passenger',
    account_status: 'active',
    last_zone_id: zoneId,
  }, { onConflict: 'id' });
  if (profileError) return await rollback('No se pudo crear el perfil Express.');

  const { error: bindingError } = await admin.from('account_runtime_bindings').insert({
    user_id: userId,
    environment: channel,
    source: 'admin_created_account',
  });
  if (bindingError) return await rollback('No se pudo asignar el entorno.');

  if (accountType === 'driver') {
    const { error: driverError } = await admin.from('driver_profiles').insert({
      id: userId,
      approval_status: 'pending',
      online_status: 'offline',
      city: zone.name,
      zone_id: zone.id,
      country_code: zone.country_code,
    });
    if (driverError) return await rollback('No se pudo preparar el perfil de conductor.');
  }

  return respond({
    user_id: userId,
    email,
    account_type: accountType,
    channel,
    temporary_password: password,
    password_disclosure: 'Se muestra una sola vez. Entrégala al usuario por un canal seguro.',
  });
});
