-- Adminexpress central access: one web app, environment/role/zone/modules by user.
-- Applied to Express Production on 2026-10-11 before this migration was committed.

alter table public.admin_users
  add column if not exists allowed_modules text[];

comment on column public.admin_users.allowed_modules is
  'Optional Adminexpress module keys. NULL means role defaults; super_admin defaults to all modules.';

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
    'allow_preview', a.allow_preview and a.access_role <> 'zone_monitor',
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

revoke all on function public.admin_access_context() from public;
revoke execute on function public.admin_access_context() from anon;
grant execute on function public.admin_access_context() to authenticated, service_role;

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

  if v_role not in ('super_admin','zone_monitor') then
    raise exception 'Rol administrativo inválido';
  end if;

  if v_environment not in ('preview','production') then
    raise exception 'Entorno administrativo inválido';
  end if;

  if v_role = 'zone_monitor' and p_zone_id is null then
    raise exception 'El monitor de zona requiere una zona';
  end if;

  if v_role = 'zone_monitor' and v_environment <> 'production' then
    raise exception 'El monitor de zona solo puede usar Producción';
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
    v_environment = 'preview' and v_role <> 'zone_monitor',
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

revoke all on function public.admin_set_panel_access_v2(uuid,text,uuid,boolean,text,text[]) from public;
revoke execute on function public.admin_set_panel_access_v2(uuid,text,uuid,boolean,text,text[]) from anon;
grant execute on function public.admin_set_panel_access_v2(uuid,text,uuid,boolean,text,text[]) to authenticated, service_role;
