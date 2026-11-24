-- Los operadores ven lo mismo que el administrador en los módulos que se les conceden.
-- Antes el detalle de viaje, de usuario y de conductor devolvía versiones recortadas para operadores
-- (sin historial de estados, calificaciones, pagos, viajes recientes, billetera, suscripción…).
-- Ahora devuelven el contenido completo; se mantiene la comprobación de módulo y de zona del
-- operador, y los documentos del conductor siguen dependiendo del permiso `drivers.view_documents`.

-- 1) Contenido completo de cada detalle, sin la puerta de super administrador (uso interno).
do $m$
declare
  v_def text; v_new text; v_pair text[];
  v_gate text := E'  if not public.is_admin() then\n    raise exception ''No autorizado'';\n  end if;\n\n';
begin
  foreach v_pair slice 1 in array array[
    array['admin_trip_detail', 'admin_trip_detail_payload'],
    array['admin_driver_detail', 'admin_driver_detail_payload'],
    array['admin_user_detail', 'admin_user_detail_payload']
  ] loop
    select pg_get_functiondef(p.oid) into v_def from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname = v_pair[1];
    v_new := replace(v_def, 'FUNCTION public.' || v_pair[1] || '(', 'FUNCTION public.' || v_pair[2] || '(');
    v_new := replace(v_new, v_gate, '');
    if v_new = v_def or v_new like '%is_admin()%' then
      raise exception 'No se pudo derivar %', v_pair[2];
    end if;
    execute v_new;
    execute format('revoke all on function public.%I(%s) from public, anon, authenticated', v_pair[2],
      'uuid');
  end loop;
end $m$;

-- 2) Los detalles para operador devuelven el contenido completo (tras comprobar módulo y zona).
create or replace function public.admin_operator_trip_detail(p_trip_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  perform public.admin_operator_assert_record('trips', 'trip', p_trip_id);
  return public.admin_trip_detail_payload(p_trip_id);
end $$;

create or replace function public.admin_operator_user_detail(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  perform public.admin_operator_assert_record('users', 'user', p_user_id);
  return public.admin_user_detail_payload(p_user_id);
end $$;

create or replace function public.admin_operator_driver_detail(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_result jsonb;
begin
  perform public.admin_operator_assert_record('drivers', 'driver', p_user_id);
  v_result := public.admin_driver_detail_payload(p_user_id);
  -- Cédula, licencia y fotos del vehículo: solo con el permiso concedido por el administrador.
  if not public.admin_can('drivers.view_documents', public.admin_zone_of_user(p_user_id)) then
    v_result := v_result || jsonb_build_object(
      'vehicles', '[]'::jsonb, 'documents', '[]'::jsonb, 'identity_verifications', '[]'::jsonb);
  end if;
  return v_result;
end $$;

-- 3) Permisos por vehículo (la ficha del conductor los lee directo de la tabla): también para el
--    operador con acceso a conductores en la zona del conductor.
drop policy if exists parcel_vehicle_grants_read_self on public.driver_parcel_vehicle_grants;
create policy parcel_vehicle_grants_read_self on public.driver_parcel_vehicle_grants for select using (
  (driver_id = (select auth.uid()))
  or public.is_admin()
  or public.admin_can('drivers.view', public.admin_zone_of_user(driver_id)));

-- 4) Conductores libres (reasignar viaje): un operador con el módulo de viajes los ve, solo de su zona.
create or replace function public.admin_operator_assert_any_module(p_modules text[])
returns void language plpgsql stable security definer set search_path to 'public' as $$
declare m text;
begin
  foreach m in array p_modules loop
    begin
      perform public.admin_operator_assert_module(m);
      return;
    exception when others then null;
    end;
  end loop;
  raise exception 'No autorizado';
end $$;
revoke all on function public.admin_operator_assert_any_module(text[]) from public, anon, authenticated;

do $m$
declare v_def text; v_new text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'admin_available_drivers_v2';
  v_new := replace(v_def,
    E'declare\n  v_channel text:=public.normalize_runtime_channel(p_channel);\nbegin',
    E'declare\n  v_channel text:=public.normalize_runtime_channel(p_channel);\n  v_zone uuid := null;\nbegin');
  v_new := replace(v_new,
    E'  if not public.is_admin() then raise exception ''No autorizado''; end if;',
    E'  if not public.is_admin() then\n    perform public.admin_operator_assert_any_module(array[''trips'', ''manual_dispatch'']);\n    v_zone := public.admin_effective_zone_id(null);\n  end if;');
  v_new := replace(v_new,
    E'    where dp.approval_status=''approved''',
    E'    where (v_zone is null or dp.zone_id = v_zone)\n      and dp.approval_status=''approved''');
  if v_new = v_def or v_new not like '%v_zone%' or position('(v_zone is null or dp.zone_id = v_zone)' in v_new) = 0
     or position('admin_operator_assert_any_module' in v_new) = 0 then
    raise exception 'No se pudo parchear admin_available_drivers_v2';
  end if;
  execute v_new;
end $m$;
