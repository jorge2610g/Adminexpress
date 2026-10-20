-- Fase 1 del cierre por zona para monitor de zona y operador.
-- 1) Las consultas por zona usan la zona del usuario cuando es monitor u operador.
-- 2) Los envíos masivos (avisos y estimaciones de audiencia) quedan solo para el administrador central.
-- 3) admin_can_access_zone reconoce al operador igual que al monitor.
-- Para el administrador central no cambia el resultado de ninguna función.
-- Fase 2 pendiente: funciones de detalle y escritura por identificador (viaje, usuario, conductor, comercio, socio).

create or replace function public.admin_zone_role_now()
returns text
language sql
stable
security definer
set search_path = public
as $function$
  select a.access_role
  from public.admin_users a
  join public.users u on u.id = a.user_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active'
  limit 1;
$function$;

create or replace function public.admin_scope_zone(p_zone_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
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

  if v_role in ('zone_monitor', 'operator') then
    if v_zone is null then
      raise exception 'Monitor sin zona asignada';
    end if;
    if p_zone_id is not null and p_zone_id is distinct from v_zone then
      raise exception 'No autorizado para esa zona';
    end if;
    return v_zone;
  end if;

  return p_zone_id;
end;
$function$;

create or replace function public.admin_block_zone_role()
returns void
language plpgsql
stable
security definer
set search_path = public
as $function$
begin
  if public.admin_zone_role_now() in ('zone_monitor', 'operator') then
    raise exception 'Esta acción solo está disponible para el administrador central';
  end if;
end;
$function$;

create or replace function public.admin_can_access_zone(p_zone_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
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

  if v_role = 'super_admin' then
    return true;
  end if;
  if v_role in ('zone_monitor', 'operator') then
    return p_zone_id is not null and p_zone_id = v_zone;
  end if;
  return false;
end;
$function$;

-- Lecturas por zona y envíos masivos: se añade la comprobación al inicio de cada función.
do $patch$
declare
  r record;
  def text;
  pos_as int;
  pos_body int;
  cut int;
  line text;
  n int := 0;
  scope_names text[] := array[
    'admin_dynamic_pricing_qa_state_scoped',
    'admin_driver_priority_state_scoped',
    'admin_identity_verification_list_scoped',
    'admin_marketplace_state_scoped',
    'admin_marketplace_v2_state',
    'admin_notification_campaign_list_scoped',
    'admin_partner_list',
    'admin_payment_overview_v2',
    'admin_preview_driver_subscription_candidates',
    'admin_special_fare_list',
    'admin_support_threads_scoped',
    'admin_trip_list_v2',
    'admin_trip_list_v3',
    'admin_user_list_v3',
    'admin_zone_coverage_get',
    'admin_zone_payment_methods',
    'admin_zone_service_list',
    'admin_distance_fare_steps_get'
  ];
  block_names text[] := array[
    'admin_send_announcement_v2',
    'admin_send_announcement_v3',
    'admin_send_announcement_v4',
    'admin_push_audience_estimate',
    'admin_push_audience_estimate_v2'
  ];
begin
  for r in
    select p.oid, p.proname, pg_get_functiondef(p.oid) as fdef
    from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public'
      and p.proname = any(scope_names || block_names)
      and p.prosecdef
      and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
  loop
    def := r.fdef;
    -- Solo las versiones que reciben p_zone_id (admin_partner_list tiene también una versión sin parámetros).
    if r.proname = any(scope_names) and pg_get_function_identity_arguments(r.oid) not like '%p_zone_id uuid%' then
      continue;
    end if;
    if position('admin_scope_zone' in def) > 0 or position('admin_block_zone_role' in def) > 0 then
      continue;
    end if;
    pos_as := position('$function$' in def);
    pos_body := position(E'\nbegin\n' in lower(substr(def, pos_as)));
    if pos_as = 0 or pos_body = 0 then
      raise exception 'No se encontró el inicio del cuerpo de %', r.proname;
    end if;
    cut := pos_as + pos_body - 1 + 7;
    if r.proname = any(block_names) then
      line := '  perform public.admin_block_zone_role();' || E'\n';
    else
      line := '  p_zone_id := public.admin_scope_zone(p_zone_id);' || E'\n';
    end if;
    execute substr(def, 1, cut) || line || substr(def, cut + 1);
    n := n + 1;
  end loop;
  if n = 0 then
    raise exception 'Ninguna función de zona fue actualizada';
  end if;
end
$patch$;
