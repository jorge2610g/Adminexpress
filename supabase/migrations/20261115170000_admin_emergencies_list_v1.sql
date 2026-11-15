-- SOS del panel: lista solo las emergencias abiertas de la zona activa.
--
-- Antes, la pantalla de SOS llamaba a admin_dashboard_state_v2 cada 10 s y
-- recibía el panel completo (conductores, viajes, envíos, actividad) solo para
-- usar la lista de emergencias. Esta función devuelve exactamente lo mismo que
-- el campo 'emergencies' de ese RPC, con los mismos controles de módulo
-- ('dashboard'), entorno y zona efectiva. Solo lectura.

create or replace function public.admin_emergencies_list_v1(
  p_channel text,
  p_zone_id uuid
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
  v_rows jsonb;
begin
  perform public.admin_operator_assert_module('dashboard');
  perform public.admin_assert_environment(v_channel);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',e.id,'channel',coalesce(et.channel,ed.channel,v_channel),
        'zone_id',ez.id,'zone_key',ez.zone_key,'zone_name',ez.name,
        'country',ez.country,'country_code',ez.country_code,
        'user_id',e.user_id,'user_name',u.full_name,
        'trip_id',e.trip_id,'delivery_id',e.delivery_id,
        'latitude',e.latitude,'longitude',e.longitude,
        'status',e.status,'created_at',e.created_at
      )
      order by e.created_at desc
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.emergency_events e
  left join public.users u on u.id=e.user_id
  left join public.trips et on et.id=e.trip_id
  left join public.ride_requests er on er.id=et.ride_request_id
  left join public.delivery_requests ed on ed.id=e.delivery_id
  left join lateral (
    select public.service_zone_id_for_point(
      ed.pickup_latitude::numeric,
      ed.pickup_longitude::numeric
    ) as zone_id
  ) edz on true
  left join public.service_zones ez
    on ez.id=coalesce(er.zone_id,edz.zone_id,u.last_zone_id)
  where ez.id=v_zone
    and coalesce(et.channel,ed.channel,v_channel)=v_channel
    and e.status not in ('resolved','closed');

  return v_rows;
end
$function$;

revoke all on function public.admin_emergencies_list_v1(text, uuid) from public, anon;
grant execute on function public.admin_emergencies_list_v1(text, uuid) to authenticated, service_role;
