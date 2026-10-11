-- PENDING SECURITY REVIEW ONLY: NOT DEPLOYED to shared Production/Preview Supabase.
-- Requires review of drivers + passengers, QA tokens, geography and existing API clients.
-- Rollback source in 20261011_dispatch_guard_original_backup.sql.

CREATE OR REPLACE FUNCTION public.admin_assign_delivery_v2(p_delivery_id uuid, p_driver_id uuid, p_channel text DEFAULT 'production'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_request_channel text;
  v_customer_id uuid;
  v_pickup_zone uuid;
  v_driver_zone uuid;
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  -- Shared project, distinct Preview/Production administrators.
  if not public.admin_environment_allowed(v_channel) then
    raise exception 'Administrador sin permiso para este entorno';
  end if;

  select channel,customer_id,
         public.service_zone_id_for_point(pickup_latitude::numeric,pickup_longitude::numeric)
  into v_request_channel,v_customer_id,v_pickup_zone
  from public.delivery_requests
  where id=p_delivery_id;

  if v_request_channel is distinct from v_channel then
    raise exception 'Delivery fuera del entorno seleccionado';
  end if;
  if exists (
    select 1 from public.audit_test_group_members m
    where m.user_id=v_customer_id and m.enabled=true
  ) <> (v_channel='preview') then
    raise exception 'Cliente fuera del entorno seleccionado';
  end if;
  select zone_id into v_driver_zone
  from public.driver_profiles where id=p_driver_id;
  if v_pickup_zone is null or v_driver_zone is distinct from v_pickup_zone then
    raise exception 'Repartidor fuera de la zona de origen';
  end if;

  if not exists(
    select 1 from public.native_push_tokens
    where user_id=p_driver_id and active=true and channel=v_channel
  ) then
    raise exception 'Conductor fuera del entorno seleccionado';
  end if;
  -- A QA identity must never be used in a Production assignment, or vice
  -- versa, even if a stale/incorrect push token has the requested channel.
  if exists (
    select 1 from public.audit_test_group_members m
    where m.user_id=p_driver_id and m.enabled=true
  ) <> (v_channel='preview') then
    raise exception 'Conductor fuera del grupo de este entorno';
  end if;

  perform set_config('app.runtime_channel',v_channel,true);
  perform public.admin_assign_delivery(p_delivery_id,p_driver_id);
end;
$function$


CREATE OR REPLACE FUNCTION public.admin_assign_ride_v2(p_ride_request_id uuid, p_driver_id uuid, p_final_fare numeric DEFAULT NULL::numeric, p_channel text DEFAULT 'production'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_request_channel text;
  v_request_zone uuid;
  v_category text;
  v_passenger_id uuid;
  v_driver_zone uuid;
  v_trip uuid;
  v_vehicle_ok boolean:=false;
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  -- Shared project, distinct Preview/Production administrators.
  if not public.admin_environment_allowed(v_channel) then
    raise exception 'Administrador sin permiso para este entorno';
  end if;

  select channel,zone_id,category,passenger_id
    into v_request_channel,v_request_zone,v_category,v_passenger_id
  from public.ride_requests
  where id=p_ride_request_id;

  if v_request_channel is distinct from v_channel then
    raise exception 'Viaje fuera del entorno seleccionado';
  end if;
  -- A Preview request must originate from a registered QA passenger.
  -- Production must never dispatch traffic created by QA passengers.
  if exists (
    select 1 from public.audit_test_group_members m
    where m.user_id=v_passenger_id and m.enabled=true
  ) <> (v_channel='preview') then
    raise exception 'Pasajero fuera del entorno seleccionado';
  end if;

  select zone_id into v_driver_zone
  from public.driver_profiles
  where id=p_driver_id;

  if v_request_zone is null
     or v_driver_zone is null
     or v_driver_zone is distinct from v_request_zone then
    raise exception 'Conductor fuera de la zona del viaje';
  end if;

  if not exists(
    select 1 from public.native_push_tokens
    where user_id=p_driver_id and active=true and channel=v_channel
  ) then
    raise exception 'Conductor fuera del entorno seleccionado';
  end if;
  -- A QA identity must never be used in a Production assignment, or vice
  -- versa, even if a stale/incorrect push token has the requested channel.
  if exists (
    select 1 from public.audit_test_group_members m
    where m.user_id=p_driver_id and m.enabled=true
  ) <> (v_channel='preview') then
    raise exception 'Conductor fuera del grupo de este entorno';
  end if;

  select exists(
    select 1
    from public.driver_vehicles dv
    where dv.driver_id=p_driver_id
      and dv.is_active=true
      and (
        (v_category='motorcycle' and dv.vehicle_type='motorcycle')
        or (v_category='xl' and dv.vehicle_type='xl')
        or (v_category in ('economy','comfort') and dv.vehicle_type in ('car','xl'))
        or (v_category not in ('motorcycle','xl','economy','comfort'))
      )
  ) into v_vehicle_ok;

  if not coalesce(v_vehicle_ok,false) then
    raise exception 'El vehículo del conductor no es compatible con la categoría del viaje';
  end if;

  perform set_config('app.runtime_channel',v_channel,true);
  v_trip:=public.admin_assign_ride(
    p_ride_request_id,p_driver_id,p_final_fare
  );
  return v_trip;
end;
$function$

