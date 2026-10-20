-- Catálogo de módulos asignables por zona: solo un despliegue separado
-- puede marcar como preparada una función nueva.
create table if not exists public.admin_operator_module_capabilities (
 module_key text primary key,
 runtime_ready boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.admin_operator_module_capabilities enable row level security;
revoke all on public.admin_operator_module_capabilities from anon,authenticated;
insert into public.admin_operator_module_capabilities(module_key,runtime_ready)
values
 ('dashboard',true),('live_operations',true),('trips',true),
 ('manual_dispatch',false),('drivers',true),('users',true),
 ('safety_sos',true),('delivery',true),('delivery_orders',false),
 ('delivery_phase2',false),('marketplace',false),('driver_priority',false),
 ('payments',false),('fares',false),('subscriptions',false),
 ('dynamic_pricing',false),('reports',false),('notifications',false),
 ('zones',false),('services',false),('geo_safety',false)
on conflict (module_key) do nothing;

-- Mantiene el contexto actual; los módulos asignados pero no preparados
-- no aparecen en el menú del operador hasta que su backend esté validado.
create or replace function public.admin_access_context()
returns jsonb language plpgsql stable security definer set search_path='public'
as $scope$
declare v_result jsonb;v_runtime text:=public.admin_current_runtime_environment();
begin
 select jsonb_build_object(
  'allowed',v_runtime in ('preview','production'),
  'role',a.access_role,'read_only',a.access_role='zone_monitor',
  'zone_id',a.zone_id,'zone_key',z.zone_key,'zone_name',z.name,
  'city',z.city,'region_department',z.region_department,
  'country',z.country,'country_code',z.country_code,
  'allow_preview',a.allow_preview and a.access_role not in ('zone_monitor','operator'),
  'allow_production',a.allow_production,'runtime_environment',v_runtime,
  'can_switch_environment',false,'default_environment',v_runtime,
  'allowed_environments',case when v_runtime in ('preview','production')
     then jsonb_build_array(v_runtime) else '[]'::jsonb end,
  'allowed_modules',case
    when a.access_role='operator' then to_jsonb(array(
      select distinct key from unnest(coalesce(a.allowed_modules,array['users']::text[])) as key
      join public.admin_operator_module_capabilities c on c.module_key=key
      where c.runtime_ready=true order by key
    ))
    when a.allowed_modules is not null then to_jsonb(a.allowed_modules)
    when a.access_role='super_admin' then to_jsonb(array['*']::text[])
    when a.access_role='zone_monitor' then to_jsonb(array[
      'dashboard','live_operations','trips','delivery','drivers','users','safety_sos','delivery_orders']::text[])
    else '[]'::jsonb end,
  'assigned_modules',case when a.access_role='operator'
    then to_jsonb(coalesce(a.allowed_modules,array['users']::text[]))
    else '[]'::jsonb end
 ) into v_result
 from public.admin_users a join public.users u on u.id=a.user_id
 left join public.service_zones z on z.id=a.zone_id
 where a.user_id=auth.uid() and a.active=true and u.account_status='active'
 limit 1;
 return coalesce(v_result,jsonb_build_object(
    'allowed',false,'allowed_modules','[]'::jsonb,'can_switch_environment',false));
end
$scope$;
