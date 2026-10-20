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
