-- Guarda a qué distancia del origen estaba cada conductor cuando se le notificó una solicitud
-- (antes solo existía en el sistema de intentos, desde 23/11).
create table if not exists public.ride_request_driver_distances (
  ride_request_id uuid not null references public.ride_requests(id) on delete cascade,
  driver_id uuid not null references public.users(id) on delete cascade,
  distance_km numeric(8,3) not null,
  location_age_seconds integer,
  recorded_at timestamptz not null default now(),
  primary key (ride_request_id, driver_id)
);
alter table public.ride_request_driver_distances enable row level security;
revoke all on public.ride_request_driver_distances from public, anon, authenticated;

create or replace function public.record_ride_request_driver_distance()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_req uuid; r public.ride_requests%rowtype; dp public.driver_profiles%rowtype;
begin
  begin
    v_req := nullif(new.metadata->>'ride_request_id', '')::uuid;
    if v_req is null then return new; end if;
    select * into r from public.ride_requests where id = v_req;
    select * into dp from public.driver_profiles where id = new.user_id;
    if r.id is null or dp.id is null or dp.latitude is null or dp.longitude is null
       or r.pickup_latitude is null or r.pickup_longitude is null then return new; end if;
    insert into public.ride_request_driver_distances (ride_request_id, driver_id, distance_km, location_age_seconds)
    values (v_req, new.user_id,
            round(public.geo_distance_km(dp.latitude, dp.longitude, r.pickup_latitude, r.pickup_longitude)::numeric, 3),
            case when dp.location_updated_at is null then null
                 else extract(epoch from (now() - dp.location_updated_at))::int end)
    on conflict do nothing;
  exception when others then
    null; -- registrar la distancia nunca debe impedir enviar la notificación
  end;
  return new;
end $$;
revoke all on function public.record_ride_request_driver_distance() from public, anon, authenticated;
drop trigger if exists record_ride_request_driver_distance on public.notifications;
create trigger record_ride_request_driver_distance after insert on public.notifications
  for each row when (new.type = 'ride_request') execute function public.record_ride_request_driver_distance();

do $m$
declare d text;
begin
  d := pg_get_functiondef('public.dispatch_request_driver_rows(uuid)'::regprocedure);
  d := replace(d, 'a.status, a.round, a.distance_km, a.responded_at,', 'a.status, a.round, coalesce(a.distance_km, dd.distance_km), a.responded_at,');
  d := replace(d, '  left join lateral (select * from public.ride_dispatch_attempts x',
    '  left join public.ride_request_driver_distances dd on dd.ride_request_id = p_request_id and dd.driver_id = i.driver_id' || E'\n' ||
    '  left join lateral (select * from public.ride_dispatch_attempts x');
  if position('ride_request_driver_distances' in d) = 0 or position('coalesce(a.distance_km, dd.distance_km)' in d) = 0 then
    raise exception 'parche de distancia no aplicado';
  end if;
  execute d;
end $m$;
