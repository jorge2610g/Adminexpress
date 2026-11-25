-- Registro de despachos: solicitudes que terminaron sin conductor, quién fue notificado, quién la vio,
-- quién respondió y a qué distancia estaba. Usa datos que ya se guardan:
--   notifications (type ride_request) + notification_delivery_events  → notificados / entregados
--   ride_request_views                                                  → vieron la solicitud
--   driver_offers                                                       → ofertaron / rechazaron / expiró
--   ride_dispatch_attempts (desde 23/11)                                → distancia al origen y ronda
-- La distancia solo existe para los despachos hechos con el sistema de intentos; las anteriores quedan en «—».

create or replace function public.admin_dispatch_scope(p_channel text, p_zone_id uuid)
returns uuid language plpgsql stable security definer set search_path to 'public' as $$
begin
  p_zone_id := public.admin_scope_zone(p_zone_id);
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  if public.admin_zone_role_now() = 'operator' then
    perform public.admin_operator_assert_module('manual_dispatch');
    p_zone_id := public.admin_effective_zone_id(p_zone_id);
  elsif not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  return p_zone_id;
end $$;
revoke all on function public.admin_dispatch_scope(text, uuid) from public, anon, authenticated;

-- Una fila por (solicitud, conductor) con todo lo que se sabe de esa interacción.
create or replace function public.dispatch_request_driver_rows(p_request_id uuid)
returns table (
  driver_id uuid, notified_at timestamptz, delivered boolean, viewed_at timestamptz,
  attempt_status text, attempt_round integer, attempt_distance_km numeric, responded_at timestamptz,
  offer_status text, offer_fare numeric, outcome text
) language sql stable security definer set search_path to 'public' as $$
  with ids as (
    select n.user_id as driver_id from public.notifications n
     where n.type = 'ride_request' and n.metadata->>'ride_request_id' = p_request_id::text
    union select v.driver_id from public.ride_request_views v where v.ride_request_id = p_request_id
    union select a.driver_id from public.ride_dispatch_attempts a where a.ride_request_id = p_request_id
    union select o.driver_id from public.driver_offers o where o.ride_request_id = p_request_id
  )
  select i.driver_id,
    (select min(n.created_at) from public.notifications n
      where n.user_id = i.driver_id and n.type = 'ride_request' and n.metadata->>'ride_request_id' = p_request_id::text),
    exists (select 1 from public.notifications n join public.notification_delivery_events e on e.notification_id = n.id
             where n.user_id = i.driver_id and n.type = 'ride_request'
               and n.metadata->>'ride_request_id' = p_request_id::text and e.event = 'provider_accepted'),
    (select v.viewed_at from public.ride_request_views v where v.ride_request_id = p_request_id and v.driver_id = i.driver_id),
    a.status, a.round, a.distance_km, a.responded_at,
    o.status, o.proposed_fare,
    case
      when a.status = 'accepted' or o.status = 'selected' then 'acepto'
      when o.status is not null and o.status <> 'declined' then 'oferto'
      when a.status = 'declined' or o.status = 'declined' then 'rechazo'
      when exists (select 1 from public.ride_request_views v where v.ride_request_id = p_request_id and v.driver_id = i.driver_id)
        then 'vio_y_no_respondio'
      else 'no_la_abrio'
    end
  from ids i
  left join lateral (select * from public.ride_dispatch_attempts x where x.ride_request_id = p_request_id
                      and x.driver_id = i.driver_id order by x.offered_at desc limit 1) a on true
  left join lateral (select * from public.driver_offers x where x.ride_request_id = p_request_id
                      and x.driver_id = i.driver_id order by x.created_at desc limit 1) o on true;
$$;
revoke all on function public.dispatch_request_driver_rows(uuid) from public, anon, authenticated;

-- Solicitudes que NO terminaron en viaje.
create or replace function public.admin_dispatch_unserved_v1(
  p_channel text, p_zone_id uuid, p_from timestamptz default null, p_to timestamptz default null, p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_zone uuid; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  v_zone := public.admin_dispatch_scope(p_channel, p_zone_id);
  if v_zone is null then return jsonb_build_object('total', 0, 'rows', '[]'::jsonb); end if;
  return (
    with reqs as (
      select r.* from public.ride_requests r
       where r.channel = v_channel and r.zone_id = v_zone
         and r.created_at >= coalesce(p_from, now() - interval '7 days')
         and r.created_at < coalesce(p_to, now() + interval '1 day')
         and r.scheduled_for is null
         and not exists (select 1 from public.trips t where t.ride_request_id = r.id)
         and r.status <> 'searching'
    ), rows as (
      select r.id, r.created_at, r.category, r.status, r.cancellation_reason, r.pickup_address, r.proposed_fare,
             r.currency, r.route_distance_km, r.dispatch_round, r.dispatch_exhausted_at, r.passenger_id,
             (select u.full_name from public.users u where u.id = r.passenger_id) passenger_name,
             s.notified, s.viewed, s.responded, s.ignored, s.unopened, s.min_km
        from reqs r
        cross join lateral (
          select count(*) filter (where d.notified_at is not null or d.attempt_status is not null)::int notified,
                 count(*) filter (where d.viewed_at is not null)::int viewed,
                 count(*) filter (where d.outcome in ('acepto','oferto','rechazo'))::int responded,
                 count(*) filter (where d.outcome = 'vio_y_no_respondio')::int ignored,
                 count(*) filter (where d.outcome = 'no_la_abrio')::int unopened,
                 min(d.attempt_distance_km) min_km
            from public.dispatch_request_driver_rows(r.id) d) s
    )
    select jsonb_build_object(
      'total', (select count(*) from rows),
      'without_notified', (select count(*) from rows where notified = 0),
      'rows', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select * from rows order by created_at desc limit greatest(1, least(coalesce(p_limit, 100), 300))) x), '[]'::jsonb)));
end $$;
revoke all on function public.admin_dispatch_unserved_v1(text, uuid, timestamptz, timestamptz, integer) from public, anon;
grant execute on function public.admin_dispatch_unserved_v1(text, uuid, timestamptz, timestamptz, integer) to authenticated;

-- Detalle: todos los conductores que tuvieron relación con una solicitud.
create or replace function public.admin_dispatch_request_drivers_v1(p_channel text, p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare r public.ride_requests%rowtype; v_zone uuid;
begin
  v_zone := public.admin_dispatch_scope(p_channel, null);
  select * into r from public.ride_requests where id = p_request_id;
  if r.id is null or r.channel <> public.normalize_runtime_channel(p_channel) then raise exception 'Solicitud no encontrada'; end if;
  if v_zone is not null and public.admin_zone_role_now() = 'operator' and r.zone_id is distinct from v_zone then
    raise exception 'Solicitud fuera de tu zona';
  end if;
  return jsonb_build_object(
    'request', jsonb_build_object('id', r.id, 'created_at', r.created_at, 'category', r.category, 'status', r.status,
      'pickup_address', r.pickup_address, 'proposed_fare', r.proposed_fare, 'currency', r.currency,
      'cancellation_reason', r.cancellation_reason, 'route_distance_km', r.route_distance_km),
    'drivers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'driver_id', d.driver_id, 'name', u.full_name, 'phone', u.phone,
        'notified_at', d.notified_at, 'delivered', d.delivered, 'viewed_at', d.viewed_at,
        'attempt_status', d.attempt_status, 'round', d.attempt_round, 'distance_km', d.attempt_distance_km,
        'responded_at', d.responded_at, 'offer_status', d.offer_status, 'offer_fare', d.offer_fare, 'outcome', d.outcome)
        order by d.attempt_distance_km nulls last, d.viewed_at nulls last)
      from public.dispatch_request_driver_rows(r.id) d join public.users u on u.id = d.driver_id), '[]'::jsonb));
end $$;
revoke all on function public.admin_dispatch_request_drivers_v1(text, uuid) from public, anon;
grant execute on function public.admin_dispatch_request_drivers_v1(text, uuid) to authenticated;

-- Por conductor: quién recibe, ve y responde (y quién ve y no responde).
create or replace function public.admin_dispatch_driver_stats_v1(
  p_channel text, p_zone_id uuid, p_from timestamptz default null, p_to timestamptz default null, p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_zone uuid; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  v_zone := public.admin_dispatch_scope(p_channel, p_zone_id);
  if v_zone is null then return '[]'::jsonb; end if;
  return coalesce((
    with reqs as (
      select r.id from public.ride_requests r
       where r.channel = v_channel and r.zone_id = v_zone and r.scheduled_for is null
         and r.created_at >= coalesce(p_from, now() - interval '7 days')
         and r.created_at < coalesce(p_to, now() + interval '1 day')
    ), pairs as (
      select d.*, q.id as req_id from reqs q cross join lateral public.dispatch_request_driver_rows(q.id) d
    ), agg as (
      select p.driver_id,
        count(*)::int notified,
        count(*) filter (where p.viewed_at is not null)::int viewed,
        count(*) filter (where p.outcome in ('acepto','oferto','rechazo'))::int responded,
        count(*) filter (where p.outcome = 'acepto' or p.outcome = 'oferto')::int took,
        count(*) filter (where p.outcome = 'rechazo')::int declined,
        count(*) filter (where p.outcome = 'vio_y_no_respondio')::int ignored,
        count(*) filter (where p.outcome = 'no_la_abrio')::int unopened,
        round(avg(p.attempt_distance_km)::numeric, 2) avg_km,
        round(max(p.attempt_distance_km)::numeric, 2) max_km
      from pairs p group by p.driver_id)
    select jsonb_agg(jsonb_build_object(
        'driver_id', a.driver_id, 'name', u.full_name, 'phone', u.phone,
        'online', dp.online_status, 'notified', a.notified, 'viewed', a.viewed, 'responded', a.responded,
        'took', a.took, 'declined', a.declined, 'ignored', a.ignored, 'unopened', a.unopened,
        'avg_km', a.avg_km, 'max_km', a.max_km,
        'response_rate', case when a.notified > 0 then round(a.responded::numeric * 100 / a.notified) end)
      order by a.ignored desc, a.unopened desc, a.notified desc)
    from (select * from agg order by ignored desc, unopened desc, notified desc
           limit greatest(1, least(coalesce(p_limit, 100), 300))) a
    join public.users u on u.id = a.driver_id
    left join public.driver_profiles dp on dp.id = a.driver_id), '[]'::jsonb);
end $$;
revoke all on function public.admin_dispatch_driver_stats_v1(text, uuid, timestamptz, timestamptz, integer) from public, anon;
grant execute on function public.admin_dispatch_driver_stats_v1(text, uuid, timestamptz, timestamptz, integer) to authenticated;
