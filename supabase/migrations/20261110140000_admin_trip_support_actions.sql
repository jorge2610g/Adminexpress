-- Acciones de soporte del administrador sobre un viaje:
--   reassign  → pasar el viaje a otro conductor en línea
--   release   → cancelar el viaje y volver a buscar conductor con una nueva solicitud
--   cancel    → cancelar el viaje (sin tarifa de cancelación)
--   start     → marcar el viaje en curso (sin PIN; requiere motivo)
--   complete  → completar el viaje (mismo cálculo que el conductor)
-- Solo super_admin. Cada acción exige motivo y queda en admin_audit_log.

create or replace function public.admin_trip_action_v1(
  p_trip_id uuid,
  p_action text,
  p_channel text default 'production',
  p_driver_id uuid default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_admin uuid := auth.uid();
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_trip public.trips%rowtype;
  v_ride public.ride_requests%rowtype;
  v_new_ride_id uuid;
  v_new_driver public.driver_profiles%rowtype;
  v_direct boolean;
  v_from text;
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  perform public.admin_assert_environment(v_channel);
  if p_action not in ('reassign', 'release', 'cancel', 'start', 'complete') then
    raise exception 'Acción inválida';
  end if;
  if v_reason is null or char_length(v_reason) < 5 then
    raise exception 'Escribe el motivo de la acción (mínimo 5 caracteres)';
  end if;

  select * into v_trip from public.trips where id = p_trip_id for update;
  if not found then
    raise exception 'Viaje no encontrado';
  end if;
  if v_trip.channel is distinct from v_channel then
    raise exception 'El viaje pertenece a otro entorno';
  end if;
  if v_trip.status = 'emergency' then
    raise exception 'El viaje está en emergencia. Resuélvela primero desde el flujo de SOS';
  end if;
  if v_trip.status in ('completed', 'cancelled') then
    raise exception 'El viaje ya finalizó';
  end if;
  select * into v_ride from public.ride_requests where id = v_trip.ride_request_id for update;
  v_from := v_trip.status;

  if p_action = 'reassign' then
    if v_trip.status not in ('driver_assigned', 'driver_arriving', 'driver_waiting') then
      raise exception 'Solo se puede reasignar antes de que empiece el viaje';
    end if;
    if p_driver_id is null or p_driver_id = v_trip.driver_id then
      raise exception 'Elige otro conductor';
    end if;
    select * into v_new_driver from public.driver_profiles where id = p_driver_id;
    if not found
       or v_new_driver.approval_status <> 'approved'
       or v_new_driver.online_status <> 'online'
       or not exists (
         select 1 from public.users u
         where u.id = p_driver_id and u.account_status = 'active'
       )
    then
      raise exception 'Conductor no disponible (debe estar aprobado y en línea)';
    end if;
    if v_new_driver.zone_id is distinct from v_ride.zone_id then
      raise exception 'El conductor no está en la zona del viaje';
    end if;
    if exists (
      select 1 from public.trips t
      where t.driver_id = p_driver_id and t.status not in ('completed', 'cancelled')
    ) or exists (
      select 1 from public.delivery_requests d
      where d.courier_id = p_driver_id and d.status not in ('delivered', 'cancelled')
    ) then
      raise exception 'El conductor ya tiene un servicio activo';
    end if;
    if not public.same_operational_scope(v_trip.passenger_id, p_driver_id) then
      raise exception 'No se puede asignar un viaje entre producción y auditoría';
    end if;

    update public.driver_profiles
      set online_status = 'online', updated_at = now()
      where id = v_trip.driver_id and approval_status = 'approved';
    update public.trips
      set driver_id = p_driver_id, status = 'driver_assigned'
      where id = p_trip_id;
    update public.driver_profiles
      set online_status = 'busy', updated_at = now()
      where id = p_driver_id;
    insert into public.trip_status_history (trip_id, status, changed_by)
      values (p_trip_id, 'driver_assigned', v_admin);
    insert into public.notifications (user_id, title, body, type) values
      (v_trip.driver_id, 'Viaje reasignado', 'Soporte asignó este viaje a otro conductor.', 'trip_status'),
      (p_driver_id, 'Viaje asignado', 'Soporte te asignó un viaje.', 'ride_assigned'),
      (v_trip.passenger_id, 'Cambio de conductor', 'Tu viaje fue asignado a otro conductor.', 'trip_status');

  elsif p_action = 'release' then
    if v_trip.status not in ('driver_assigned', 'driver_arriving', 'driver_waiting') then
      raise exception 'Solo se puede liberar antes de que empiece el viaje';
    end if;
    update public.trips
      set status = 'cancelled', cancellation_reason = 'Liberado por soporte: ' || v_reason
      where id = p_trip_id;
    insert into public.trip_status_history (trip_id, status, changed_by)
      values (p_trip_id, 'cancelled', v_admin);
    update public.driver_profiles
      set online_status = 'online', updated_at = now()
      where id = v_trip.driver_id and approval_status = 'approved';
    update public.ride_requests
      set status = 'cancelled', cancellation_reason = 'Liberado por soporte', updated_at = now()
      where id = v_ride.id;
    -- Nueva solicitud con los mismos datos para que vuelva a buscar conductor.
    -- (trips.ride_request_id es único, por eso el viaje nuevo va en otra solicitud).
    insert into public.ride_requests
      select (jsonb_populate_record(
        null::public.ride_requests,
        to_jsonb(v_ride) || jsonb_build_object(
          'id', gen_random_uuid(),
          'status', 'searching',
          'cancellation_reason', null,
          'created_at', now(),
          'updated_at', now(),
          'expires_at', now() + interval '3 minutes'
        )
      )).*
    returning id into v_new_ride_id;
    update public.driver_offers
      set status = 'expired'
      where ride_request_id = v_ride.id and status in ('selected', 'declined');
    insert into public.notifications (user_id, title, body, type) values
      (v_trip.driver_id, 'Viaje liberado', 'Soporte liberó este viaje.', 'trip_status'),
      (v_trip.passenger_id, 'Viaje cancelado', 'Tu viaje fue cancelado por soporte. Puedes pedir uno nuevo.', 'trip_cancelled');

  elsif p_action = 'cancel' then
    if v_trip.status not in ('driver_assigned', 'driver_arriving', 'driver_waiting') then
      raise exception 'Solo se puede cancelar antes de que empiece el viaje';
    end if;
    update public.trips
      set status = 'cancelled', cancellation_reason = 'Cancelado por soporte: ' || v_reason
      where id = p_trip_id;
    insert into public.trip_status_history (trip_id, status, changed_by)
      values (p_trip_id, 'cancelled', v_admin);
    update public.ride_requests
      set status = 'cancelled', cancellation_reason = 'Cancelado por soporte', updated_at = now()
      where id = v_ride.id;
    update public.driver_profiles
      set online_status = 'online', updated_at = now()
      where id = v_trip.driver_id and approval_status = 'approved';
    insert into public.notifications (user_id, title, body, type) values
      (v_trip.driver_id, 'Viaje cancelado', 'Soporte canceló este viaje.', 'trip_cancelled'),
      (v_trip.passenger_id, 'Viaje cancelado', 'Tu viaje fue cancelado por soporte.', 'trip_cancelled');

  elsif p_action = 'start' then
    if v_trip.status not in ('driver_assigned', 'driver_arriving', 'driver_waiting') then
      raise exception 'El viaje no puede iniciarse desde este estado';
    end if;
    update public.trips set status = 'in_progress' where id = p_trip_id;
    insert into public.trip_status_history (trip_id, status, changed_by)
      values (p_trip_id, 'in_progress', v_admin);
    insert into public.notifications (user_id, title, body, type) values
      (v_trip.passenger_id, 'Viaje en curso', 'Tu viaje ya está en curso.', 'trip_status');

  elsif p_action = 'complete' then
    if v_trip.status <> 'in_progress' then
      raise exception 'Solo se puede completar un viaje en curso';
    end if;
    v_direct := v_ride.payment_method in ('cash', 'driver_qr');
    update public.trips
      set status = 'completed',
          completed_at = now(),
          payment_status = case when v_direct then 'paid' else payment_status end
      where id = p_trip_id;
    insert into public.trip_status_history (trip_id, status, changed_by)
      values (p_trip_id, 'completed', v_admin);
    insert into public.payment_transactions (
      payer_id, payee_id, trip_id, method, amount, currency, status, paid_at
    ) values (
      v_trip.passenger_id, v_trip.driver_id, p_trip_id, v_ride.payment_method,
      coalesce(v_trip.final_fare, v_ride.proposed_fare, 0),
      coalesce(v_ride.currency, 'BOB'),
      case when v_direct then 'paid' else 'pending' end,
      case when v_direct then now() else null end
    ) on conflict (trip_id) where trip_id is not null do nothing;
    update public.driver_profiles
      set completed_trips = completed_trips + 1, online_status = 'online', updated_at = now()
      where id = v_trip.driver_id;
    insert into public.notifications (user_id, title, body, type) values
      (v_trip.passenger_id, 'Llegaste a destino', 'Tu viaje finalizó. Ya puedes calificar al conductor.', 'trip_status'),
      (v_trip.driver_id, 'Viaje completado', 'El viaje quedó registrado en tus ganancias.', 'trip_completed');
  end if;

  perform public.admin_log_action(
    'trip_support_' || p_action,
    'trips',
    p_trip_id::text,
    jsonb_strip_nulls(jsonb_build_object(
      'reason', v_reason,
      'from_status', v_from,
      'previous_driver_id', v_trip.driver_id,
      'new_driver_id', p_driver_id,
      'new_ride_request_id', v_new_ride_id,
      'payment_method', v_ride.payment_method
    ))
  );

  return jsonb_build_object(
    'ok', true,
    'trip_id', p_trip_id,
    'action', p_action,
    'from_status', v_from,
    'new_ride_request_id', v_new_ride_id
  );
end;
$function$;

revoke all on function public.admin_trip_action_v1(uuid, text, text, uuid, text) from public, anon;
grant execute on function public.admin_trip_action_v1(uuid, text, text, uuid, text) to authenticated;
