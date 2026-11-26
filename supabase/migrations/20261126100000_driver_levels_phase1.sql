-- Niveles de conductor (fase 1): Inicio, Pro y Élite, calculados con los últimos N días (30 por defecto).
-- Fase 1 solo informa: no cambia quién recibe las solicitudes ni mueve dinero.
create table if not exists public.driver_level_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default true,
  window_days integer not null default 30 check (window_days between 7 and 90),
  pro_min_trips integer not null default 12 check (pro_min_trips >= 1),
  elite_min_trips integer not null default 30 check (elite_min_trips >= 1),
  pro_min_rating numeric(3,2) not null default 4.70 check (pro_min_rating between 1 and 5),
  elite_min_rating numeric(3,2) not null default 4.85 check (elite_min_rating between 1 and 5),
  pro_min_response numeric(5,2) not null default 30 check (pro_min_response between 0 and 100),
  elite_min_response numeric(5,2) not null default 50 check (elite_min_response between 0 and 100),
  pro_max_cancel numeric(5,2) not null default 15 check (pro_max_cancel between 0 and 100),
  elite_max_cancel numeric(5,2) not null default 8 check (elite_max_cancel between 0 and 100),
  min_notified_for_response integer not null default 10 check (min_notified_for_response >= 0),
  min_ratings_for_rating integer not null default 3 check (min_ratings_for_rating >= 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id) on delete set null
);
insert into public.driver_level_settings(id) values (true) on conflict do nothing;
alter table public.driver_level_settings enable row level security;
revoke all on public.driver_level_settings from public, anon, authenticated;

-- Métricas y nivel de un conductor en la ventana configurada.
create or replace function public.driver_level_compute(p_driver uuid, p_channel text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  s public.driver_level_settings%rowtype; v_ws timestamptz; v_channel text := public.normalize_runtime_channel(p_channel);
  v_trips int; v_rating numeric; v_rcount int; v_notified int; v_responded int; v_resp numeric;
  v_cancel_n int; v_cancel numeric; v_flags int; v_level text; v_next text; v_crit jsonb := '[]'::jsonb;
  v_resp_ok boolean; v_rating_ok boolean;
begin
  select * into s from public.driver_level_settings where id;
  v_ws := now() - make_interval(days => s.window_days);

  select count(*) into v_trips from public.trips t
   where t.driver_id = p_driver and t.status = 'completed' and t.channel = v_channel and coalesce(t.completed_at, t.created_at) >= v_ws;

  select round(avg(r.score)::numeric, 2), count(*) into v_rating, v_rcount from public.ratings r
   where r.to_user_id = p_driver and coalesce(r.rated_role, 'driver') = 'driver' and r.created_at >= v_ws;

  with notified as (
    select distinct (n.metadata->>'ride_request_id')::uuid as id from public.notifications n
     where n.user_id = p_driver and n.type = 'ride_request' and n.created_at >= v_ws
       and n.metadata->>'ride_request_id' ~* '^[0-9a-f-]{36}$'
  ), responded as (
    select o.ride_request_id as id from public.driver_offers o where o.driver_id = p_driver and o.created_at >= v_ws
    union select a.ride_request_id from public.ride_dispatch_attempts a
           where a.driver_id = p_driver and a.status in ('accepted', 'declined') and a.offered_at >= v_ws
  )
  select (select count(*) from notified), (select count(*) from responded) into v_notified, v_responded;
  v_notified := greatest(v_notified, v_responded);
  v_resp := case when v_notified > 0 then round(v_responded::numeric * 100 / v_notified, 1) else null end;

  select count(*) into v_cancel_n from public.trips t
   where t.driver_id = p_driver and t.status = 'cancelled' and t.channel = v_channel and t.created_at >= v_ws
     and exists (select 1 from public.trip_status_history h where h.trip_id = t.id and h.status = 'cancelled' and h.changed_by = p_driver);
  v_cancel := case when v_trips + v_cancel_n > 0 then round(v_cancel_n::numeric * 100 / (v_trips + v_cancel_n), 1) else 0 end;

  select count(*) into v_flags from public.trip_integrity_flags f
   where f.driver_id = p_driver and f.review_status in ('open', 'confirmed') and f.created_at >= v_ws;

  v_resp_ok := v_notified < s.min_notified_for_response;     -- sin datos suficientes: no se exige
  v_rating_ok := v_rcount < s.min_ratings_for_rating;

  v_level := case
    when v_trips >= s.elite_min_trips and (v_rating_ok or v_rating >= s.elite_min_rating)
         and (v_resp_ok or v_resp >= s.elite_min_response) and v_cancel <= s.elite_max_cancel and v_flags = 0 then 'elite'
    when v_trips >= s.pro_min_trips and (v_rating_ok or v_rating >= s.pro_min_rating)
         and (v_resp_ok or v_resp >= s.pro_min_response) and v_cancel <= s.pro_max_cancel and v_flags = 0 then 'pro'
    else 'inicio' end;
  v_next := case v_level when 'inicio' then 'pro' when 'pro' then 'elite' else null end;

  if v_next is not null then
    v_crit := jsonb_build_array(
      jsonb_build_object('key', 'trips', 'label', 'Viajes completados', 'unit', 'viajes', 'higher_is_better', true,
        'value', v_trips, 'target', case v_next when 'pro' then s.pro_min_trips else s.elite_min_trips end,
        'met', v_trips >= case v_next when 'pro' then s.pro_min_trips else s.elite_min_trips end),
      jsonb_build_object('key', 'rating', 'label', 'Calificación', 'unit', 'estrellas', 'higher_is_better', true,
        'value', v_rating, 'target', case v_next when 'pro' then s.pro_min_rating else s.elite_min_rating end,
        'met', v_rating_ok or v_rating >= case v_next when 'pro' then s.pro_min_rating else s.elite_min_rating end),
      jsonb_build_object('key', 'response', 'label', 'Respuesta a solicitudes', 'unit', '%', 'higher_is_better', true,
        'value', v_resp, 'target', case v_next when 'pro' then s.pro_min_response else s.elite_min_response end,
        'met', v_resp_ok or v_resp >= case v_next when 'pro' then s.pro_min_response else s.elite_min_response end),
      jsonb_build_object('key', 'cancel', 'label', 'Cancelaciones', 'unit', '%', 'higher_is_better', false,
        'value', v_cancel, 'target', case v_next when 'pro' then s.pro_max_cancel else s.elite_max_cancel end,
        'met', v_cancel <= case v_next when 'pro' then s.pro_max_cancel else s.elite_max_cancel end),
      jsonb_build_object('key', 'integrity', 'label', 'Viajes sospechosos abiertos', 'unit', '', 'higher_is_better', false,
        'value', v_flags, 'target', 0, 'met', v_flags = 0));
  end if;

  return jsonb_build_object(
    'enabled', s.enabled, 'level', v_level, 'next_level', v_next, 'window_days', s.window_days,
    'metrics', jsonb_build_object('trips', v_trips, 'rating', v_rating, 'rating_count', v_rcount,
      'response_rate', v_resp, 'notified', v_notified, 'responded', v_responded,
      'cancel_rate', v_cancel, 'cancelled_by_driver', v_cancel_n, 'integrity_flags', v_flags),
    'criteria', v_crit,
    'thresholds', jsonb_build_object(
      'pro', jsonb_build_object('trips', s.pro_min_trips, 'rating', s.pro_min_rating, 'response', s.pro_min_response, 'cancel', s.pro_max_cancel),
      'elite', jsonb_build_object('trips', s.elite_min_trips, 'rating', s.elite_min_rating, 'response', s.elite_min_response, 'cancel', s.elite_max_cancel)));
end $$;
revoke all on function public.driver_level_compute(uuid, text) from public, anon, authenticated;

create or replace function public.my_driver_level_v1(p_channel text default 'production')
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or not public.is_account_active() then raise exception 'No autorizado'; end if;
  if not exists (select 1 from public.driver_profiles where id = v_uid) then
    return jsonb_build_object('enabled', false, 'reason', 'not_driver');
  end if;
  return public.driver_level_compute(v_uid, p_channel);
end $$;
revoke all on function public.my_driver_level_v1(text) from public, anon;
grant execute on function public.my_driver_level_v1(text) to authenticated;

create or replace function public.admin_driver_levels_v1(p_channel text, p_zone_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_zone uuid; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  v_zone := public.admin_driver_requests_scope(p_channel, p_zone_id);
  if v_zone is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(x.j order by (case x.j->>'level' when 'elite' then 0 when 'pro' then 1 else 2 end),
                                  (x.j->'metrics'->>'trips')::int desc)
    from (
      select jsonb_build_object('driver_id', dp.id, 'name', u.full_name, 'phone', u.phone, 'online', dp.online_status) ||
             public.driver_level_compute(dp.id, v_channel) as j
        from public.driver_profiles dp join public.users u on u.id = dp.id
       where dp.zone_id = v_zone and dp.approval_status = 'approved' and public.comm_user_in_channel(dp.id, v_channel)
    ) x), '[]'::jsonb);
end $$;
revoke all on function public.admin_driver_levels_v1(text, uuid) from public, anon;
grant execute on function public.admin_driver_levels_v1(text, uuid) to authenticated;

create or replace function public.admin_driver_level_settings_get_v1()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  return (select to_jsonb(s) - 'id' from public.driver_level_settings s where id);
end $$;
revoke all on function public.admin_driver_level_settings_get_v1() from public, anon;
grant execute on function public.admin_driver_level_settings_get_v1() to authenticated;

create or replace function public.admin_driver_level_settings_update_v1(p jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare s public.driver_level_settings%rowtype;
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  select * into s from public.driver_level_settings where id for update;
  update public.driver_level_settings set
    enabled = coalesce((p->>'enabled')::boolean, s.enabled),
    window_days = coalesce((p->>'window_days')::int, s.window_days),
    pro_min_trips = coalesce((p->>'pro_min_trips')::int, s.pro_min_trips),
    elite_min_trips = coalesce((p->>'elite_min_trips')::int, s.elite_min_trips),
    pro_min_rating = coalesce((p->>'pro_min_rating')::numeric, s.pro_min_rating),
    elite_min_rating = coalesce((p->>'elite_min_rating')::numeric, s.elite_min_rating),
    pro_min_response = coalesce((p->>'pro_min_response')::numeric, s.pro_min_response),
    elite_min_response = coalesce((p->>'elite_min_response')::numeric, s.elite_min_response),
    pro_max_cancel = coalesce((p->>'pro_max_cancel')::numeric, s.pro_max_cancel),
    elite_max_cancel = coalesce((p->>'elite_max_cancel')::numeric, s.elite_max_cancel),
    updated_at = now(), updated_by = auth.uid()
  where id;
  if (select elite_min_trips < pro_min_trips from public.driver_level_settings where id) then
    raise exception 'Élite debe pedir al menos tantos viajes como Pro';
  end if;
  perform public.admin_log_action('driver_level_settings_update', 'driver_level_settings', 'global', p);
  return (select to_jsonb(x) - 'id' from public.driver_level_settings x where id);
end $$;
revoke all on function public.admin_driver_level_settings_update_v1(jsonb) from public, anon;
grant execute on function public.admin_driver_level_settings_update_v1(jsonb) to authenticated;
