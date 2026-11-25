-- Resumen de despachos por día: cuántas solicitudes entran, cuántas se concretan, cuántos conductores
-- son notificados, cuántos la ven y cuántos responden. Para auditar si los usuarios piden y los
-- conductores no aceptan.
create or replace function public.admin_dispatch_summary_v1(
  p_channel text, p_zone_id uuid, p_from timestamptz default null, p_to timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_zone uuid; v_channel text := public.normalize_runtime_channel(p_channel); v_tz text;
begin
  v_zone := public.admin_dispatch_scope(p_channel, p_zone_id);
  if v_zone is null then return jsonb_build_object('totals', '{}'::jsonb, 'days', '[]'::jsonb); end if;
  select coalesce(nullif(z.timezone, ''), 'UTC') into v_tz from public.service_zones z where z.id = v_zone;
  v_tz := coalesce(v_tz, 'UTC');
  return (
    with reqs as (
      select r.id, r.status, (r.created_at at time zone v_tz)::date as day,
             exists (select 1 from public.trips t where t.ride_request_id = r.id) as has_trip
        from public.ride_requests r
       where r.channel = v_channel and r.zone_id = v_zone and r.scheduled_for is null
         and r.created_at >= coalesce(p_from, now() - interval '7 days')
         and r.created_at < coalesce(p_to, now() + interval '1 day')
    ), per as (
      select q.day, q.id, q.has_trip, q.status, s.notified, s.viewed, s.responded, s.ignored, s.unopened, s.drivers
        from reqs q
        cross join lateral (
          select count(*) filter (where d.notified_at is not null or d.attempt_status is not null)::int notified,
                 count(*) filter (where d.viewed_at is not null)::int viewed,
                 count(*) filter (where d.outcome in ('acepto','oferto','rechazo'))::int responded,
                 count(*) filter (where d.outcome = 'vio_y_no_respondio')::int ignored,
                 count(*) filter (where d.outcome = 'no_la_abrio')::int unopened,
                 array_agg(d.driver_id) as drivers
            from public.dispatch_request_driver_rows(q.id) d) s
    ), days as (
      select day,
             count(*)::int requests,
             count(*) filter (where has_trip)::int concretadas,
             count(*) filter (where not has_trip and status <> 'searching')::int sin_concretar,
             count(*) filter (where not has_trip and status = 'searching')::int buscando,
             count(*) filter (where notified = 0)::int sin_notificados,
             coalesce(sum(notified), 0)::int notificaciones,
             coalesce(sum(viewed), 0)::int vistas,
             coalesce(sum(responded), 0)::int respuestas,
             coalesce(sum(ignored), 0)::int ignoradas,
             coalesce(sum(unopened), 0)::int sin_abrir
        from per group by day
    ), drv as (
      select (p.day) as day, count(distinct dr) as n
        from per p, lateral unnest(coalesce(p.drivers, '{}'::uuid[])) dr group by p.day
    )
    select jsonb_build_object(
      'timezone', v_tz,
      'online_now', (select count(*) from public.driver_profiles dp
                      where dp.zone_id = v_zone and dp.online_status = 'online' and dp.approval_status = 'approved'),
      'totals', jsonb_build_object(
        'requests', coalesce((select sum(requests) from days), 0),
        'concretadas', coalesce((select sum(concretadas) from days), 0),
        'sin_concretar', coalesce((select sum(sin_concretar) from days), 0),
        'buscando', coalesce((select sum(buscando) from days), 0),
        'sin_notificados', coalesce((select sum(sin_notificados) from days), 0),
        'notificaciones', coalesce((select sum(notificaciones) from days), 0),
        'vistas', coalesce((select sum(vistas) from days), 0),
        'respuestas', coalesce((select sum(respuestas) from days), 0),
        'ignoradas', coalesce((select sum(ignoradas) from days), 0),
        'sin_abrir', coalesce((select sum(sin_abrir) from days), 0),
        'conductores_notificados', (select count(distinct dr) from per p, lateral unnest(coalesce(p.drivers, '{}'::uuid[])) dr)),
      'days', coalesce((select jsonb_agg(jsonb_build_object(
          'day', d.day, 'requests', d.requests, 'concretadas', d.concretadas, 'sin_concretar', d.sin_concretar,
          'buscando', d.buscando, 'sin_notificados', d.sin_notificados, 'notificaciones', d.notificaciones,
          'vistas', d.vistas, 'respuestas', d.respuestas, 'ignoradas', d.ignoradas, 'sin_abrir', d.sin_abrir,
          'conductores_notificados', coalesce((select n from drv where drv.day = d.day), 0))
        order by d.day desc) from days d), '[]'::jsonb)));
end $$;
revoke all on function public.admin_dispatch_summary_v1(text, uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_dispatch_summary_v1(text, uuid, timestamptz, timestamptz) to authenticated;

-- «Sin conductor» pasa a incluir también las solicitudes que siguen buscando conductor
-- (todas las que no se concretaron), con su estado visible.
do $m$
declare d text;
begin
  d := pg_get_functiondef('public.admin_dispatch_unserved_v1(text,uuid,timestamptz,timestamptz,integer)'::regprocedure);
  d := replace(d, E'         and r.status <> ''searching''\n', '');
  if position('r.status <> ''searching''' in d) > 0 then raise exception 'no se pudo ajustar el filtro'; end if;
  execute d;
end $m$;
