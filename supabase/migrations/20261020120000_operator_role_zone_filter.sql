-- Rol «operator» (operador de zona). Solo añade el rol y el listado de accesos.
-- Alcance por zona igual que zone_monitor: el servidor devuelve solo la zona asignada.
-- Los módulos que ve cada operador se guardan en admin_users.allowed_modules
-- (lo elige el administrador central desde la pantalla Operadores).
-- No cambia permisos de super_admin ni de zone_monitor.

-- 0) Roles permitidos en admin_users: super_admin, zone_monitor y operator.
--    Antes la restricción solo admitía super_admin y zone_monitor.
alter table public.admin_users drop constraint if exists admin_users_access_role_check;
alter table public.admin_users add constraint admin_users_access_role_check
  check (access_role = any (array['super_admin'::text, 'zone_monitor'::text, 'operator'::text]));

-- El operador, igual que el monitor de zona, siempre tiene una zona asignada.
alter table public.admin_users drop constraint if exists admin_users_zone_monitor_scope_check;
alter table public.admin_users add constraint admin_users_zone_monitor_scope_check
  check (access_role not in ('zone_monitor'::text, 'operator'::text) or zone_id is not null);

-- 1) Operador y monitor: la zona efectiva no admite otra zona distinta a la asignada.
create or replace function public.admin_effective_zone_id(p_requested_zone_id uuid default null::uuid)
returns uuid
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_role text;
  v_zone uuid;
begin
  select a.access_role, a.zone_id
    into v_role, v_zone
  from public.admin_users a
  join public.users u on u.id = a.user_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active'
  limit 1;

  if v_role is null then
    raise exception 'No autorizado';
  end if;

  if v_role in ('zone_monitor', 'operator') then
    if v_zone is null then
      raise exception 'Monitor sin zona asignada';
    end if;
    if p_requested_zone_id is not null
       and p_requested_zone_id is distinct from v_zone then
      raise exception 'No autorizado para esa zona';
    end if;
    return v_zone;
  end if;

  if v_role = 'super_admin' then
    if p_requested_zone_id is null then
      raise exception 'Selecciona país y zona antes de cargar datos';
    end if;
    return p_requested_zone_id;
  end if;

  raise exception 'No autorizado';
end;
$function$;

-- 2) El rol operator se acepta como panel administrativo.
do $patch$
declare
  def text;
  old_txt constant text := 'a.access_role in (''super_admin'',''zone_monitor'')';
  new_txt constant text := 'a.access_role in (''super_admin'',''zone_monitor'',''operator'')';
begin
  select pg_get_functiondef(p.oid) into def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'admin_has_panel_access';
  if def is null then
    raise exception 'admin_has_panel_access no existe';
  end if;
  if position(new_txt in def) > 0 then
    return;
  end if;
  if (length(def) - length(replace(def, old_txt, ''))) / length(old_txt) <> 1 then
    raise exception 'admin_has_panel_access: patrón no encontrado una sola vez';
  end if;
  execute replace(def, old_txt, new_txt);
end
$patch$;

-- 3) Contexto de acceso: el operador no es solo lectura y no entra a Prueba.
--    Si el administrador guardó módulos, se usan esos; si no, un conjunto por defecto.
create or replace function public.admin_access_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_result jsonb;
  v_runtime text := public.admin_current_runtime_environment();
begin
  select jsonb_build_object(
    'allowed', v_runtime in ('preview','production'),
    'role', a.access_role,
    'read_only', a.access_role = 'zone_monitor',
    'zone_id', a.zone_id,
    'zone_key', z.zone_key,
    'zone_name', z.name,
    'city', z.city,
    'region_department', z.region_department,
    'country', z.country,
    'country_code', z.country_code,
    'allow_preview', a.allow_preview and a.access_role not in ('zone_monitor','operator'),
    'allow_production', a.allow_production,
    'runtime_environment', v_runtime,
    'can_switch_environment', false,
    'default_environment', v_runtime,
    'allowed_environments',
      case
        when v_runtime in ('preview','production') then jsonb_build_array(v_runtime)
        else '[]'::jsonb
      end,
    'allowed_modules',
      case
        when a.allowed_modules is not null then to_jsonb(a.allowed_modules)
        when a.access_role = 'super_admin' then to_jsonb(array['*']::text[])
        when a.access_role = 'zone_monitor' then to_jsonb(array[
          'dashboard','live_operations','trips','delivery','drivers',
          'users','safety_sos','delivery_orders'
        ]::text[])
        when a.access_role = 'operator' then to_jsonb(array[
          'dashboard','live_operations','trips','drivers','users','safety_sos'
        ]::text[])
        else '[]'::jsonb
      end
  )
  into v_result
  from public.admin_users a
  join public.users u on u.id = a.user_id
  left join public.service_zones z on z.id = a.zone_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active'
  limit 1;

  return coalesce(
    v_result,
    jsonb_build_object(
      'allowed', false,
      'allowed_modules', '[]'::jsonb,
      'can_switch_environment', false
    )
  );
end;
$function$;

-- 4) Asignación de acceso (solo administrador central): acepta el rol operator.
create or replace function public.admin_set_panel_access_v2(
  p_user_id uuid,
  p_access_role text,
  p_zone_id uuid,
  p_active boolean,
  p_environment text,
  p_allowed_modules text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_role text := lower(trim(coalesce(p_access_role,'')));
  v_environment text := lower(trim(coalesce(p_environment,'')));
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;

  if v_role not in ('super_admin','zone_monitor','operator') then
    raise exception 'Rol administrativo inválido';
  end if;

  if v_environment not in ('preview','production') then
    raise exception 'Entorno administrativo inválido';
  end if;

  if v_role in ('zone_monitor','operator') and p_zone_id is null then
    raise exception 'Este rol requiere una zona asignada';
  end if;

  if v_role in ('zone_monitor','operator') and v_environment <> 'production' then
    raise exception 'Este rol solo puede usar Producción';
  end if;

  if p_allowed_modules is not null and exists (
    select 1 from unnest(p_allowed_modules) x
    where nullif(trim(x),'') is null
  ) then
    raise exception 'Los permisos de módulos contienen valores vacíos';
  end if;

  insert into public.admin_users(
    user_id, access_role, zone_id, active, allow_preview, allow_production,
    allowed_modules, updated_at
  )
  values(
    p_user_id,
    v_role,
    p_zone_id,
    coalesce(p_active,true),
    v_environment = 'preview' and v_role not in ('zone_monitor','operator'),
    v_environment = 'production',
    p_allowed_modules,
    now()
  )
  on conflict (user_id) do update
  set access_role = excluded.access_role,
      zone_id = excluded.zone_id,
      active = excluded.active,
      allow_preview = excluded.allow_preview,
      allow_production = excluded.allow_production,
      allowed_modules = excluded.allowed_modules,
      updated_at = now();

  insert into public.account_runtime_bindings(
    user_id, environment, source, bound_at, updated_at
  )
  values(
    p_user_id, v_environment, 'admin_access_v2', now(), now()
  )
  on conflict (user_id) do update
  set environment = excluded.environment,
      source = excluded.source,
      updated_at = now();

  return jsonb_build_object(
    'user_id', p_user_id,
    'access_role', v_role,
    'zone_id', p_zone_id,
    'active', coalesce(p_active,true),
    'environment', v_environment,
    'allowed_modules', coalesce(to_jsonb(p_allowed_modules), 'null'::jsonb)
  );
end;
$function$;

-- 5) Listado de accesos para la pantalla Operadores (solo administrador central).
create or replace function public.admin_panel_access_list()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.access_role desc, t.email)
    from (
      select a.user_id, au.email, u.full_name, a.access_role, a.active, a.zone_id,
             z.name as zone_name, z.city, z.country, z.country_code,
             b.environment as runtime_environment, a.allowed_modules, a.updated_at
      from public.admin_users a
      join public.users u on u.id = a.user_id
      left join auth.users au on au.id = a.user_id
      left join public.service_zones z on z.id = a.zone_id
      left join public.account_runtime_bindings b on b.user_id = a.user_id
    ) t
  ), '[]'::jsonb);
end;
$function$;

revoke all on function public.admin_panel_access_list() from public;
revoke execute on function public.admin_panel_access_list() from anon;
grant execute on function public.admin_panel_access_list() to authenticated, service_role;

-- 6) Búsqueda de cuentas existentes en toda la base (solo administrador central).
create or replace function public.admin_panel_user_search(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_query text := lower(trim(coalesce(p_query,'')));
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  if length(v_query) < 3 then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t))
    from (
      select u.id as user_id, au.email, u.full_name, u.account_status
      from public.users u
      left join auth.users au on au.id = u.id
      where lower(coalesce(au.email,'')) like '%' || v_query || '%'
         or lower(coalesce(u.full_name,'')) like '%' || v_query || '%'
      order by u.full_name nulls last
      limit 25
    ) t
  ), '[]'::jsonb);
end;
$function$;

revoke all on function public.admin_panel_user_search(text) from public;
revoke execute on function public.admin_panel_user_search(text) from anon;
grant execute on function public.admin_panel_user_search(text) to authenticated, service_role;
