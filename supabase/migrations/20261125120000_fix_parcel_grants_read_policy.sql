-- La política de lectura de driver_parcel_vehicle_grants llamaba directamente a admin_zone_of_user,
-- función sin permiso de ejecución para `authenticated`. Resultado: toda consulta desde el panel
-- (y desde la app) fallaba con «permission denied for function admin_zone_of_user».
-- La comprobación pasa a una función SECURITY DEFINER.
create or replace function public.can_read_driver_parcel_grants(p_driver uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select p_driver = auth.uid()
      or public.is_admin()
      or coalesce(public.admin_can('drivers.view', public.admin_zone_of_user(p_driver)), false);
$$;
revoke all on function public.can_read_driver_parcel_grants(uuid) from public, anon;
grant execute on function public.can_read_driver_parcel_grants(uuid) to authenticated;

drop policy if exists parcel_vehicle_grants_read_self on public.driver_parcel_vehicle_grants;
create policy parcel_vehicle_grants_read_self on public.driver_parcel_vehicle_grants for select
  using (public.can_read_driver_parcel_grants(driver_id));
