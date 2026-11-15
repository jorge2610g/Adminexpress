-- Ranking de viajes completados para exportar desde Adminexpress.
--
-- Solo lectura. Devuelve, por conductor o por pasajero de la zona activa,
-- el número de viajes con estado 'completed'. Usa la misma regla de canal y
-- zona que la lista de viajes (trips + ride_requests) y los mismos controles
-- de módulo y entorno que las listas de conductores y usuarios.
-- Conductores: módulo 'drivers'. Pasajeros: módulo 'users'.

create or replace function public.admin_completed_trip_ranking_v1(
  p_channel text,
  p_zone_id uuid,
  p_role text
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_role text := lower(trim(coalesce(p_role, '')));
begin
  if v_role not in ('driver', 'passenger') then
    raise exception 'Rol no válido para el ranking de viajes' using errcode = '22023';
  end if;
  perform public.admin_operator_assert_module(
    case when v_role = 'driver' then 'drivers' else 'users' end
  );
  perform public.admin_assert_environment(v_channel);

  return (
    select coalesce(
      jsonb_agg(to_jsonb(x) order by x.completed_trips desc, x.full_name, x.user_id),
      '[]'::jsonb
    )
    from (
      select
        ranked.user_id,
        coalesce(max(u.full_name), '') as full_name,
        count(*)::int as completed_trips,
        min(ranked.completed_at) as first_completed_at,
        max(ranked.completed_at) as last_completed_at
      from (
        select
          case when v_role = 'driver' then t.driver_id else t.passenger_id end as user_id,
          t.completed_at
        from public.trips t
        join public.ride_requests rr on rr.id = t.ride_request_id
        where t.status = 'completed'
          and t.channel = v_channel
          and rr.channel = v_channel
          and rr.zone_id = v_zone
      ) ranked
      left join public.users u on u.id = ranked.user_id
      where ranked.user_id is not null
      group by ranked.user_id
    ) x
  );
end
$function$;

revoke all on function public.admin_completed_trip_ranking_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_completed_trip_ranking_v1(text, uuid, text) to authenticated, service_role;
