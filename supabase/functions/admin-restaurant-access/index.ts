// Cambia el correo de acceso o establece una contraseña temporal para el
// propietario asignado a un restaurante. Solo Admin puede invocarla.
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
  const { data: isAdmin, error: adminError } = await caller.rpc('is_admin');
  if (adminError || isAdmin !== true) return respond({ error: 'Solo Admin puede modificar accesos.' }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return respond({ error: 'Datos inválidos.' }, 400); }
  const merchantId = String(body.merchant_id ?? '').trim();
  const userId = String(body.user_id ?? '').trim();
  const newEmail = String(body.new_email ?? '').trim().toLowerCase();
  const generatePassword = body.generate_password === true;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(merchantId) ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)) {
    return respond({ error: 'Restaurante o usuario inválido.' }, 400);
  }
  if (newEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) {
    return respond({ error: 'Correo no válido.' }, 400);
  }
  if (!newEmail && !generatePassword) return respond({ error: 'Indica un correo nuevo o solicita una contraseña temporal.' }, 400);

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: membership, error: membershipError } = await admin
    .from('marketplace_merchant_users')
    .select('user_id,role,active')
    .eq('merchant_id', merchantId)
    .eq('user_id', userId)
    .maybeSingle();
  if (membershipError || !membership || membership.active !== true || membership.role !== 'owner') {
    return respond({ error: 'El usuario no es el propietario activo de este restaurante.' }, 403);
  }

  const password = generatePassword ? temporaryPassword() : undefined;
  const updates: Record<string, unknown> = {};
  if (newEmail) {
    updates.email = newEmail;
    updates.email_confirm = true;
  }
  if (password) updates.password = password;
  const { error: updateError } = await admin.auth.admin.updateUserById(userId, updates);
  if (updateError) return respond({ error: 'Supabase no pudo actualizar el acceso.' }, 400);

  return respond({
    user_id: userId,
    email: newEmail || null,
    temporary_password: password ?? null,
    password_disclosure: password
      ? 'Se muestra una sola vez. Entrégala al propietario por un canal seguro.'
      : null,
  });
});
