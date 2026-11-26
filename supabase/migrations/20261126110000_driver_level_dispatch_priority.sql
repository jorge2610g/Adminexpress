-- Fase 2 de niveles: el nivel pesa en el despacho.
--  1) Aviso de precio fijo (despacho secuencial): entre los conductores casi igual de cerca (hasta
--     dispatch_tolerance_km más lejos que el más cercano) se avisa primero a Élite, luego Pro y luego Inicio.
--     Fuera de esa franja se mantiene el orden por distancia, para no hacer esperar de más al pasajero.
--  2) Lista de solicitudes del conductor: Élite = cercanía + pasajeros mejor calificados; Pro = cercanía;
--     Inicio = orden de llegada.
-- Se puede apagar con driver_level_settings.dispatch_priority_enabled.
alter table public.driver_level_settings add column if not exists dispatch_priority_enabled boolean not null default true;
alter table public.driver_level_settings add column if not exists dispatch_tolerance_km numeric(4,1) not null default 1.0
  check (dispatch_tolerance_km between 0 and 10);

-- Caché del nivel (se recalcula si tiene más de 30 minutos) para no calcularlo en cada aviso.
create table if not exists public.driver_level_cache (
  driver_id uuid not null references public.users(id) on delete cascade,
  channel text not null,
  level text not null,
  computed_at timestamptz not null default now(),
  primary key (driver_id, channel)
);
alter table public.driver_level_cache enable row level security;
revoke all on public.driver_level_cache from public, anon, authenticated;

create or replace function public.driver_level_cached(p_driver uuid, p_channel text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); c public.driver_level_cache%rowtype; v_level text;
begin
  select * into c from public.driver_level_cache where driver_id = p_driver and channel = v_channel;
  if c.driver_id is not null and c.computed_at > now() - interval '30 minutes' then return c.level; end if;
  begin
    v_level := coalesce(public.driver_level_compute(p_driver, v_channel)->>'level', 'inicio');
  exception when others then
    return coalesce(c.level, 'inicio');
  end;
  insert into public.driver_level_cache(driver_id, channel, level, computed_at) values (p_driver, v_channel, v_level, now())
  on conflict (driver_id, channel) do update set level = excluded.level, computed_at = excluded.computed_at;
  return v_level;
end $$;
revoke all on function public.driver_level_cached(uuid, text) from public, anon, authenticated;

create or replace function public.driver_level_rank(p_driver uuid, p_channel text)
returns integer language sql security definer set search_path to 'public' as $$
  select case public.driver_level_cached(p_driver, p_channel) when 'elite' then 0 when 'pro' then 1 else 2 end;
$$;
revoke all on function public.driver_level_rank(uuid, text) from public, anon, authenticated;

do $m$
declare d text; a int; b int; new_block text;
begin
  -- 1) Despacho secuencial de precio fijo
  d := pg_get_functiondef('public.fixed_dispatch_advance_v1(uuid)'::regprocedure);
  a := position('  select c.driver_id, c.distance_km into v_next' in d);
  b := position('  limit 1;' in substr(d, a)) + a - 1;
  if a = 0 or b <= a then raise exception 'no se encontró el bloque de selección del siguiente conductor'; end if;
  new_block :=
'  with cands as (
    select c.driver_id, c.distance_km
      from public.ride_dispatch_candidates(v_ride, 0, v_max) c
     where not exists (select 1 from public.ride_dispatch_attempts a where a.ride_request_id = v_ride.id and a.driver_id = c.driver_id)
       and not public.driver_has_active_trip(c.driver_id)
       and not exists (select 1 from public.ride_dispatch_attempts a2 where a2.driver_id = c.driver_id and a2.status = ''pending'' and a2.expires_at > now())
       and public.fixed_dispatch_vehicle_ok(c.driver_id, v_ride.category)
  ), cfg as (
    select coalesce((select dispatch_priority_enabled from public.driver_level_settings where id), false) as on_,
           coalesce((select dispatch_tolerance_km from public.driver_level_settings where id), 1.0) as tol
  ), near as (select min(distance_km) as d0 from cands)
  select c.driver_id, c.distance_km into v_next
    from cands c cross join cfg cross join near
   order by case when cfg.on_ and c.distance_km <= near.d0 + cfg.tol then public.driver_level_rank(c.driver_id, v_ride.channel) else 9 end,
            c.distance_km asc
   limit 1;';
  d := substr(d, 1, a - 1) || new_block || substr(d, b + length('  limit 1;'));
  if position('driver_level_rank' in d) = 0 then raise exception 'parche de despacho no aplicado'; end if;
  execute d;

  -- 2) Lista de solicitudes del conductor
  d := pg_get_functiondef('public.available_ride_requests_for_driver_v2(text)'::regprocedure);
  if position('v_level:=coalesce(v_priority->>''level'',''medium'');' in d) = 0 then
    raise exception 'no se encontró la asignación de nivel en la lista de solicitudes';
  end if;
  d := replace(d, 'v_level:=coalesce(v_priority->>''level'',''medium'');',
    'v_level:=case when coalesce((select dispatch_priority_enabled from public.driver_level_settings where id), false)' || E'\n' ||
    '    then (case public.driver_level_cached(v_uid, v_channel) when ''elite'' then ''high'' when ''pro'' then ''medium'' else ''low'' end)' || E'\n' ||
    '    else coalesce(v_priority->>''level'',''medium'') end;');
  execute d;
end $m$;

-- Ajustes: los dos campos nuevos se leen y se guardan con las demás.
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
    dispatch_priority_enabled = coalesce((p->>'dispatch_priority_enabled')::boolean, s.dispatch_priority_enabled),
    dispatch_tolerance_km = coalesce((p->>'dispatch_tolerance_km')::numeric, s.dispatch_tolerance_km),
    updated_at = now(), updated_by = auth.uid()
  where id;
  if (select elite_min_trips < pro_min_trips from public.driver_level_settings where id) then
    raise exception 'Élite debe pedir al menos tantos viajes como Pro';
  end if;
  delete from public.driver_level_cache;  -- los cambios de umbrales se aplican de inmediato
  perform public.admin_log_action('driver_level_settings_update', 'driver_level_settings', 'global', p);
  return (select to_jsonb(x) - 'id' from public.driver_level_settings x where id);
end $$;
revoke all on function public.admin_driver_level_settings_update_v1(jsonb) from public, anon;
grant execute on function public.admin_driver_level_settings_update_v1(jsonb) to authenticated;
