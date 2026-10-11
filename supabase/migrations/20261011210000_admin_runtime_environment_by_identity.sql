-- Mirror/versioning of the migration already applied on 2026-10-11.
-- One canonical Adminexpress web app; runtime environment is bound to identity.

insert into public.account_runtime_bindings
  (user_id, environment, source, bound_at, updated_at)
select
  a.user_id,
  case
    when a.allow_preview = true and a.allow_production = false then 'preview'
    when a.allow_production = true and a.allow_preview = false then 'production'
    else null
  end,
  'admin_identity_binding',
  now(),
  now()
from public.admin_users a
where a.active = true
  and (
    (a.allow_preview = true and a.allow_production = false)
    or
    (a.allow_production = true and a.allow_preview = false)
  )
on conflict (user_id) do update
set environment = excluded.environment,
    source = excluded.source,
    updated_at = now();

create or replace function public.admin_current_runtime_environment()
returns text
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_environment text;
  v_allow_preview boolean := false;
  v_allow_production boolean := false;
  v_role text;
begin
  select a.allow_preview, a.allow_production, a.access_role
    into v_allow_preview, v_allow_production, v_role
  from public.admin_users a
  join public.users u on u.id = a.user_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active'
  limit 1;

  if not found then
    return null;
  end if;

  if v_role = 'zone_monitor' then
    return case when v_allow_production then 'production' else null end;
  end if;

  select b.environment
    into v_environment
  from public.account_runtime_bindings b
  where b.user_id = auth.uid();

  if v_environment = 'preview' and v_allow_preview then
    return 'preview';
  end if;

  if v_environment = 'production' and v_allow_production then
    return 'production';
  end if;

  if v_allow_preview and not v_allow_production then
    return 'preview';
  end if;

  if v_allow_production and not v_allow_preview then
    return 'production';
  end if;

  if v_allow_production then
    return 'production';
  end if;

  if v_allow_preview then
    return 'preview';
  end if;

  return null;
end;
$function$;

revoke all on function public.admin_current_runtime_environment() from public;
revoke all on function public.admin_current_runtime_environment() from anon;
grant execute on function public.admin_current_runtime_environment() to authenticated;
grant execute on function public.admin_current_runtime_environment() to service_role;

create or replace function public.admin_environment_allowed(p_channel text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_channel text := lower(trim(coalesce(p_channel,'')));
  v_runtime text;
  v_allowed boolean := false;
begin
  if v_channel not in ('preview','production') then
    return false;
  end if;

  v_runtime := public.admin_current_runtime_environment();
  if v_runtime is null or v_runtime <> v_channel then
    return false;
  end if;

  select case
    when v_channel = 'preview' then a.allow_preview and a.access_role <> 'zone_monitor'
    else a.allow_production
  end
  into v_allowed
  from public.admin_users a
  join public.users u on u.id = a.user_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active'
  limit 1;

  return coalesce(v_allowed,false);
end;
$function$;

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

  return coalesce(v_result, jsonb_build_object('allowed',false));
end;
$function$;
