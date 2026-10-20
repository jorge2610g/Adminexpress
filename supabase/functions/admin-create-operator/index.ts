// Crea una cuenta de operador con correo y contraseña y le asigna zona y módulos.
// Solo la puede llamar un administrador central: la sesión del llamador se comprueba con is_admin().
// PENDIENTE DE DESPLIEGUE: esta función no está publicada en Supabase hasta que el propietario lo autorice.
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
  const requested = Array.isArray(body.allowed_modules) ? body.allowed_modules.map(String) : [];
  // Usuarios siempre va incluido como base del operador.
  const modules = Array.from(
    new Set(['users', ...requested.map((m) => m.trim()).filter((m) => m.length > 0)]),
  );

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return respond({ error: 'Correo no válido.' }, 400);
  }
  if (password.length < 8) {
    return respond({ error: 'La contraseña debe tener al menos 8 caracteres.' }, 400);
  }
  if (!zoneId) {
    return respond({ error: 'Elige la zona del operador.' }, 400);
  }

  // La clave de servicio solo se usa aquí, para crear la cuenta de acceso.
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
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
  await admin
    .from('users')
    .upsert({ id: userId, full_name: fullName || null }, { onConflict: 'id', ignoreDuplicates: true });

  const { error: accessError } = await caller.rpc('admin_set_panel_access_v2', {
    p_user_id: userId,
    p_access_role: 'operator',
    p_zone_id: zoneId,
    p_active: true,
    p_environment: 'production',
    p_allowed_modules: modules,
  });
  if (accessError) {
    return respond(
      {
        error: 'La cuenta se creó, pero no se pudo asignar el acceso: ' + accessError.message,
        user_id: userId,
      },
      422,
    );
  }

  return respond({ ok: true, user_id: userId, email, allowed_modules: modules });
});
