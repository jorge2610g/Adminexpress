// Crea una cuenta de operador con correo y contraseña y le asigna zona y módulos.
// Solo la puede llamar un administrador central: la sesión del llamador se comprueba con is_admin().
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function respond(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return respond({ error: 'Método no permitido.' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return respond({ error: 'Inicia sesión como administrador.' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Cliente con la sesión del administrador: las funciones SQL comprueban quién hace la llamada.
  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  const { data: signedIn, error: identityError } = await caller.auth.getUser(token);
  if (identityError || !signedIn.user) {
    return respond({ error: 'Sesión caducada. Inicia sesión otra vez.' }, 401);
  }
  const { data: isAdmin, error: adminError } = await caller.rpc('is_admin');
  if (adminError || isAdmin !== true) {
    return respond({ error: 'Solo el administrador central puede crear operadores.' }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return respond({ error: 'Datos no válidos.' }, 400);
  }

  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');
  const fullName = String(body.full_name ?? '').trim();
  const zoneId = String(body.zone_id ?? '').trim();
  // Solo funciones cuya autorización por módulo y zona está verificada en Supabase.
  const supported = new Set(['users', 'dashboard', 'trips', 'drivers']);
  if (body.allowed_modules != null && !Array.isArray(body.allowed_modules)) {
    return respond({ error: 'Permisos de módulos inválidos.' }, 400);
  }
  const requested = (Array.isArray(body.allowed_modules) ? body.allowed_modules : [])
    .map((module) => String(module).trim());
  if (requested.some((module) => !supported.has(module))) {
    return respond({ error: 'Hay módulos todavía no habilitados para operadores.' }, 400);
  }
  const modules = Array.from(new Set(['users', ...requested]));

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return respond({ error: 'Correo no válido.' }, 400);
  }
  if (password.length < 8) {
    return respond({ error: 'La contraseña debe tener al menos 8 caracteres.' }, 400);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(zoneId)) {
    return respond({ error: 'Elige una zona válida para el operador.' }, 400);
  }

  // La clave de servicio solo se usa aquí, para crear la cuenta de acceso.
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  // La zona debe existir y estar activa: no confiar en un UUID enviado por el navegador.
  const { data: zone, error: zoneError } = await admin.from('service_zones')
    .select('id,active').eq('id', zoneId).maybeSingle();
  if (zoneError || zone?.active !== true) {
    return respond({ error: 'La zona seleccionada no está disponible.' }, 400);
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createError || !created.user) {
    return respond({ error: createError?.message ?? 'No se pudo crear la cuenta.' }, 400);
  }
  const userId = created.user.id;

  // El disparador on_auth_user_created crea la fila de perfil; esto solo cubre el caso en que falte.
  const { error: profileError } = await admin
    .from('users')
    .upsert({ id: userId, full_name: fullName || null }, { onConflict: 'id', ignoreDuplicates: true });
  if (profileError) {
    const { error: cleanupError } = await admin.auth.admin.deleteUser(userId);
    return respond(cleanupError
      ? { error: 'No se pudo completar el perfil. Revisar la cuenta creada antes de reintentar.', user_id: userId }
      : { error: 'No se pudo crear el perfil. No se activó el operador.' }, 422);
  }

  const { error: accessError } = await caller.rpc('admin_set_panel_access_v2', {
    p_user_id: userId,
    p_access_role: 'operator',
    p_zone_id: zoneId,
    p_active: true,
    p_environment: 'production',
    p_allowed_modules: modules,
  });
  if (accessError) {
    const { error: cleanupError } = await admin.auth.admin.deleteUser(userId);
    return respond(cleanupError
      ? { error: 'No se pudo asignar el acceso y quedó una cuenta pendiente de revisión.', user_id: userId }
      : { error: 'No se pudo asignar el acceso. Se canceló el alta de operador.' }, 422);
  }

  return respond({ ok: true, user_id: userId, email, allowed_modules: modules });
});
