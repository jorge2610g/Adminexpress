-- Granular actions per operator module. Existing operators keep their current
-- module grants until an administrator saves an explicit action matrix.
alter table public.admin_users
  add column if not exists module_permissions jsonb;

alter table public.admin_users
  drop constraint if exists admin_users_module_permissions_object_check;
alter table public.admin_users
  add constraint admin_users_module_permissions_object_check
  check (module_permissions is null or jsonb_typeof(module_permissions) = 'object');

comment on column public.admin_users.module_permissions is
  'Per-module operator capabilities: view, edit and delete booleans. NULL preserves legacy module behavior.';

-- Existing active operators keep their current module visibility but move to
-- read-only until the owner explicitly grants edit/delete per module.
update public.admin_users a
set module_permissions = coalesce((
  select jsonb_object_agg(
    selected.module_key,
    jsonb_build_object('view', true, 'edit', false, 'delete', false)
  )
  from (
    select distinct requested.module_key
    from unnest(
      case
        when 'users' = any(coalesce(a.allowed_modules, array[]::text[]))
          then coalesce(a.allowed_modules, array[]::text[])
        else array_append(coalesce(a.allowed_modules, array[]::text[]), 'users')
      end
    ) as requested(module_key)
  ) selected
  join public.admin_operator_module_capabilities c
    on c.module_key = selected.module_key
), '{}'::jsonb)
where a.access_role = 'operator' and a.active = true;

create or replace function public.admin_set_operator_module_access(
  p_user_id uuid,
  p_zone_id uuid,
  p_active boolean,
  p_allowed_modules text[],
  p_module_permissions jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_existing_role text;
  v_modules text[] := array(
    select distinct requested.module_key
    from unnest(coalesce(p_allowed_modules, array[]::text[])) as requested(module_key)
  );
  v_entry record;
  v_actions jsonb;
  v_action text;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  if public.admin_current_runtime_environment() <> 'production'
     or not coalesce(public.admin_environment_allowed('production'), false) then
    raise exception 'La asignación de operadores solo puede administrarse desde Producción';
  end if;
  if p_user_id is null or p_zone_id is null then
    raise exception 'El operador requiere una cuenta y una zona';
  end if;
  if not exists (select 1 from public.service_zones z where z.id = p_zone_id and z.active = true) then
    raise exception 'La zona seleccionada no está disponible';
  end if;
  select a.access_role into v_existing_role
    from public.admin_users a where a.user_id = p_user_id;
  if v_existing_role is not null and v_existing_role <> 'operator' then
    raise exception 'Esta cuenta ya tiene otro rol administrativo';
  end if;
  if not ('users' = any(v_modules)) then
    v_modules := array_append(v_modules, 'users');
  end if;
  if exists (
    select 1 from unnest(v_modules) as requested(module_key)
    where not exists (
      select 1 from public.admin_operator_module_capabilities c
      where c.module_key = requested.module_key
    )
  ) then
    raise exception 'El permiso elegido no pertenece al catálogo de operadores';
  end if;
  if jsonb_typeof(coalesce(p_module_permissions, '{}'::jsonb)) <> 'object' then
    raise exception 'Los permisos por módulo deben ser un objeto';
  end if;

  for v_entry in select key, value from jsonb_each(coalesce(p_module_permissions, '{}'::jsonb))
  loop
    if not (v_entry.key = any(v_modules)) then
      raise exception 'Hay permisos para un módulo que no está seleccionado';
    end if;
    if jsonb_typeof(v_entry.value) <> 'object' then
      raise exception 'Los permisos de cada módulo deben ser un objeto';
    end if;
    if exists (
      select 1 from jsonb_object_keys(v_entry.value) as keys(action_key)
      where keys.action_key not in ('view', 'edit', 'delete')
    ) then
      raise exception 'Acción de operador desconocida';
    end if;
    for v_action in select unnest(array['view', 'edit', 'delete'])
    loop
      v_actions := v_entry.value;
      if v_actions ? v_action and jsonb_typeof(v_actions -> v_action) <> 'boolean' then
        raise exception 'Cada permiso debe ser verdadero o falso';
      end if;
    end loop;
    if (coalesce((v_entry.value ->> 'edit')::boolean, false)
        or coalesce((v_entry.value ->> 'delete')::boolean, false))
       and not coalesce((v_entry.value ->> 'view')::boolean, false) then
      raise exception 'Editar o borrar requiere permiso para ver';
    end if;
  end loop;

  insert into public.admin_users(
    user_id, access_role, zone_id, active, allow_preview, allow_production,
    allowed_modules, module_permissions, updated_at
  ) values (
    p_user_id, 'operator', p_zone_id, coalesce(p_active, true), false, true,
    v_modules, coalesce(p_module_permissions, '{}'::jsonb), now()
  )
  on conflict (user_id) do update
  set access_role = 'operator', zone_id = excluded.zone_id,
      active = excluded.active, allow_preview = false, allow_production = true,
      allowed_modules = excluded.allowed_modules,
      module_permissions = excluded.module_permissions, updated_at = now();

  insert into public.account_runtime_bindings(user_id, environment, source, bound_at, updated_at)
  values (p_user_id, 'production', 'admin_operator_access', now(), now())
  on conflict (user_id) do update
  set environment = 'production', source = 'admin_operator_access', updated_at = now();

  return jsonb_build_object(
    'user_id', p_user_id,
    'access_role', 'operator',
    'zone_id', p_zone_id,
    'active', coalesce(p_active, true),
    'allowed_modules', to_jsonb(v_modules),
    'module_permissions', coalesce(p_module_permissions, '{}'::jsonb)
  );
end;
$function$;

revoke all on function public.admin_set_operator_module_access(uuid, uuid, boolean, text[], jsonb) from public, anon;
grant execute on function public.admin_set_operator_module_access(uuid, uuid, boolean, text[], jsonb) to authenticated, service_role;

create or replace function public.admin_operator_assert_module_action(
  p_module text,
  p_action text
) returns void
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_zone uuid;
  v_modules text[];
  v_permissions jsonb;
begin
  if p_action is null or p_action not in ('view', 'edit', 'delete') then
    raise exception 'Acción de operador inválida';
  end if;
  select a.access_role, a.zone_id, a.allowed_modules, a.module_permissions
    into v_role, v_zone, v_modules, v_permissions
  from public.admin_users a
  join public.users u on u.id = a.user_id
  where a.user_id = auth.uid() and a.active = true and u.account_status = 'active';
  if v_role is null then raise exception 'No autorizado'; end if;
  if v_role = 'super_admin' then return; end if;
  if v_role = 'zone_monitor' then
    if p_action = 'view' and p_module = any(array[
      'dashboard', 'users', 'drivers', 'trips', 'marketplace', 'delivery',
      'delivery_orders', 'partners'
    ]::text[]) then return; end if;
    raise exception 'Acción reservada para operadores autorizados';
  end if;
  if v_role <> 'operator' or v_zone is null
     or not coalesce(public.admin_environment_allowed('production'), false)
     or public.admin_current_runtime_environment() <> 'production'
     or not (p_module = any(coalesce(v_modules, array[]::text[])))
     or not exists (
       select 1 from public.admin_operator_module_capabilities c
       where c.module_key = p_module and c.runtime_ready = true
     ) then
    raise exception 'Módulo sin autorización para esta zona';
  end if;
  if v_permissions is not null
     and coalesce((v_permissions -> p_module ->> p_action)::boolean, false) is not true then
    raise exception 'Acción no autorizada para este módulo';
  end if;
end;
$function$;

revoke all on function public.admin_operator_assert_module_action(text, text) from public, anon;
grant execute on function public.admin_operator_assert_module_action(text, text) to authenticated, service_role;

create or replace function public.admin_operator_assert_module(p_module text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  perform public.admin_operator_assert_module_action(p_module, 'view');
end;
$function$;

revoke all on function public.admin_operator_assert_module(text) from public, anon;
grant execute on function public.admin_operator_assert_module(text) to authenticated, service_role;

-- Expose only the saved operator grants to the authenticated panel. Existing
-- roles keep their established module behavior.
create or replace function public.admin_access_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare v_result jsonb; v_runtime text := public.admin_current_runtime_environment();
begin
  select jsonb_build_object(
    'allowed', v_runtime in ('preview', 'production'),
    'role', a.access_role,
    'read_only', a.access_role = 'zone_monitor',
    'zone_id', a.zone_id, 'zone_key', z.zone_key, 'zone_name', z.name,
    'city', z.city, 'region_department', z.region_department,
    'country', z.country, 'country_code', z.country_code,
    'allow_preview', a.allow_preview and a.access_role not in ('zone_monitor', 'operator'),
    'allow_production', a.allow_production,
    'runtime_environment', v_runtime,
    'can_switch_environment', false,
    'default_environment', v_runtime,
    'allowed_environments', case when v_runtime in ('preview', 'production')
      then jsonb_build_array(v_runtime) else '[]'::jsonb end,
    'allowed_modules', case
      when a.access_role = 'operator' then to_jsonb(array(
        select distinct assigned.module_key
        from unnest(coalesce(a.allowed_modules, array['users']::text[])) as assigned(module_key)
        join public.admin_operator_module_capabilities c on c.module_key = assigned.module_key
        where c.runtime_ready = true
          and (a.module_permissions is null or
            coalesce((a.module_permissions -> assigned.module_key ->> 'view')::boolean, false))
        order by assigned.module_key
      ))
      when a.allowed_modules is not null then to_jsonb(a.allowed_modules)
      when a.access_role = 'super_admin' then to_jsonb(array['*']::text[])
      when a.access_role = 'zone_monitor' then to_jsonb(array[
        'dashboard','live_operations','trips','delivery','drivers','users','safety_sos','delivery_orders'
      ]::text[])
      else '[]'::jsonb end,
    'assigned_modules', case when a.access_role = 'operator'
      then to_jsonb(coalesce(a.allowed_modules, array['users']::text[])) else '[]'::jsonb end,
    'module_permissions', case when a.access_role = 'operator'
      then coalesce(a.module_permissions, '{}'::jsonb) else '{}'::jsonb end
  ) into v_result
  from public.admin_users a
  join public.users u on u.id = a.user_id
  left join public.service_zones z on z.id = a.zone_id
  where a.user_id = auth.uid() and a.active = true and u.account_status = 'active'
  limit 1;
  return coalesce(v_result, jsonb_build_object(
    'allowed', false, 'allowed_modules', '[]'::jsonb,
    'module_permissions', '{}'::jsonb, 'can_switch_environment', false
  ));
end;
$function$;

revoke all on function public.admin_access_context() from public;
revoke execute on function public.admin_access_context() from anon;
grant execute on function public.admin_access_context() to authenticated, service_role;

create or replace function public.admin_panel_access_list()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.access_role desc, t.email)
    from (
      select a.user_id, au.email, u.full_name, a.access_role, a.active, a.zone_id,
        z.name as zone_name, z.city, z.country, z.country_code,
        b.environment as runtime_environment, a.allowed_modules,
        a.module_permissions, a.updated_at
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

-- Gate existing operator write RPCs at the database boundary. Read RPCs keep
-- the one-argument module check; older accounts without an explicit matrix
-- retain legacy behavior until their permissions are edited and saved.
do $patch$
declare r record; v_def text;
begin
  for r in
    select p.oid, p.proname, pg_get_functiondef(p.oid) as definition
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'admin_operator_upsert_fare_rule',
      'admin_operator_upsert_subscription_plan',
      'admin_send_announcement_v4',
      'admin_landing_banner_save_v1',
      'admin_finance_settle_adjustment_debt_v1',
      'admin_finance_adjust_wallet_v1',
      'admin_wallet_debt_limits_set_v1',
      'admin_finance_settle_debt_v1'
    )
  loop
    v_def := r.definition;
    v_def := replace(v_def, 'perform public.admin_operator_assert_module(''fares'');',
      'perform public.admin_operator_assert_module_action(''fares'', ''edit'');');
    v_def := replace(v_def, 'perform public.admin_operator_assert_module(''subscriptions'');',
      'perform public.admin_operator_assert_module_action(''subscriptions'', ''edit'');');
    v_def := replace(v_def, 'perform public.admin_operator_assert_module(''notifications'');',
      'perform public.admin_operator_assert_module_action(''notifications'', ''edit'');');
    v_def := replace(v_def, 'perform public.admin_operator_assert_module(''marketplace'');',
      'perform public.admin_operator_assert_module_action(''marketplace'', ''edit'');');
    v_def := replace(v_def, 'perform public.admin_operator_assert_module(''payments'');',
      'perform public.admin_operator_assert_module_action(''payments'', ''edit'');');
    if v_def = r.definition then
      raise exception 'No se encontró la comprobación esperada en %', r.proname;
    end if;
    execute v_def;
  end loop;

  for r in
    select p.oid, p.proname, pg_get_functiondef(p.oid) as definition
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'admin_operator_update_contact', 'admin_update_user_profile_v2'
    )
  loop
    v_def := r.definition;
    v_def := replace(v_def,
      'perform public.admin_operator_assert_record(''users'',''user'',p_user_id);',
      'perform public.admin_operator_assert_record(''users'',''user'',p_user_id);' || E'\n    perform public.admin_operator_assert_module_action(''users'', ''edit'');');
    v_def := replace(v_def,
      'perform public.admin_operator_assert_record(''drivers'',''driver'',p_user_id);',
      'perform public.admin_operator_assert_record(''drivers'',''driver'',p_user_id);' || E'\n    perform public.admin_operator_assert_module_action(''drivers'', ''edit'');');
    if v_def = r.definition then
      raise exception 'No se encontró la comprobación de edición esperada en %', r.proname;
    end if;
    execute v_def;
  end loop;
end;
$patch$;
