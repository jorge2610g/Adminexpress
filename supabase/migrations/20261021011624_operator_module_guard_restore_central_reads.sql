-- Central admins and read-only monitors still use shared read RPCs guarded by
-- this function. Keep their read surface while denying operator finance/write
-- modules; operators retain the production, zone and capability checks below.
create or replace function public.admin_operator_assert_module(p_module text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $guard$
declare
  v_role text;
  v_zone uuid;
  v_modules text[];
begin
  select a.access_role, a.zone_id, a.allowed_modules
    into v_role, v_zone, v_modules
  from public.admin_users a
  join public.users u on u.id = a.user_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active';

  if v_role is null then
    raise exception 'No autorizado';
  end if;

  if v_role in ('super_admin', 'zone_monitor')
     and p_module = any(array[
       'dashboard', 'users', 'drivers', 'trips', 'marketplace', 'delivery',
       'delivery_orders', 'partners'
     ]::text[])
  then
    return;
  end if;

  if v_role is distinct from 'operator'
     or v_zone is null
     or p_module is null
     or not coalesce(public.admin_environment_allowed('production'), false)
     or public.admin_current_runtime_environment() <> 'production'
     or not (p_module = any(coalesce(v_modules, array[]::text[])))
     or not exists (
       select 1
       from public.admin_operator_module_capabilities c
       where c.module_key = p_module
         and c.runtime_ready = true
     )
  then
    raise exception 'Modulo sin autorizacion para esta zona';
  end if;
end
$guard$;
