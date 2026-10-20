-- Tarifas editables únicamente en la zona del operador.
-- Requiere el catálogo de capacidades: habilitar 'fares' tras las pruebas.
create or replace function public.admin_operator_fare_list(p_zone_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public'
as $body$
declare v_zone uuid;
begin
 perform public.admin_operator_assert_module('fares');
 v_zone:=public.admin_effective_zone_id(p_zone_id);
 return coalesce((
  select jsonb_agg(to_jsonb(f) || jsonb_build_object('zone_name',z.name,'zone_city',z.city)
    order by f.service_key)
  from public.fare_rules f join public.service_zones z on z.id=f.zone_id
  where f.scope_type='zone_service' and f.zone_id=v_zone
 ),'[]'::jsonb);
end
$body$;

create or replace function public.admin_operator_service_list()
returns jsonb language plpgsql stable security definer set search_path='public'
as $body$
begin
 perform public.admin_operator_assert_module('fares');
 return coalesce((select jsonb_agg(to_jsonb(s) order by s.sort_order,s.name)
                  from public.service_catalog s),'[]'::jsonb);
end
$body$;

create or replace function public.admin_operator_upsert_fare_rule(
 p_id uuid,p_zone_id uuid,p_service_key text,p_base_fare numeric,
 p_per_km numeric,p_per_minute numeric,p_minimum_fare numeric,
 p_surge_multiplier numeric,p_commission_percent numeric,p_active boolean
) returns uuid language plpgsql security definer set search_path='public'
as $body$
declare v_zone uuid; v_id uuid;
begin
 perform public.admin_operator_assert_module('fares');
 v_zone:=public.admin_effective_zone_id(p_zone_id);
 if nullif(trim(coalesce(p_service_key,'')),'') is null
    or not exists(select 1 from public.service_catalog s where s.service_key=p_service_key)
 then raise exception 'Servicio invalido';end if;
 if p_id is not null and not exists(
    select 1 from public.fare_rules f
    where f.id=p_id and f.zone_id=v_zone and f.scope_type='zone_service'
 ) then raise exception 'No se puede modificar una tarifa de otra zona o global';end if;
 if p_id is null then
  insert into public.fare_rules(scope_type,service_key,zone_id,
    base_fare,per_km,per_minute,minimum_fare,surge_multiplier,
    commission_percent,active)
  values('zone_service',p_service_key,v_zone,
    greatest(coalesce(p_base_fare,0),0),greatest(coalesce(p_per_km,0),0),
    greatest(coalesce(p_per_minute,0),0),greatest(coalesce(p_minimum_fare,0),0),
    greatest(coalesce(p_surge_multiplier,1),1),
    least(greatest(coalesce(p_commission_percent,0),0),100),coalesce(p_active,true))
  returning id into v_id;
 else
  update public.fare_rules
  set service_key=p_service_key,base_fare=greatest(coalesce(p_base_fare,0),0),
    per_km=greatest(coalesce(p_per_km,0),0),
    per_minute=greatest(coalesce(p_per_minute,0),0),
    minimum_fare=greatest(coalesce(p_minimum_fare,0),0),
    surge_multiplier=greatest(coalesce(p_surge_multiplier,1),1),
    commission_percent=least(greatest(coalesce(p_commission_percent,0),0),100),
    active=coalesce(p_active,true)
  where id=p_id and zone_id=v_zone and scope_type='zone_service'
  returning id into v_id;
 end if;
 if v_id is null then raise exception 'Tarifa no guardada'; end if;
 insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,details)
 values(auth.uid(),'operator_fare_upsert','fare_rules',v_id::text,
   jsonb_build_object('zone_id',v_zone,'service',p_service_key));
 return v_id;
end
$body$;

revoke all on function public.admin_operator_fare_list(uuid) from public,anon;
revoke all on function public.admin_operator_service_list() from public,anon;
revoke all on function public.admin_operator_upsert_fare_rule(
uuid,uuid,text,numeric,numeric,numeric,numeric,numeric,numeric,boolean) from public,anon;
grant execute on function public.admin_operator_fare_list(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_service_list() to authenticated,service_role;
grant execute on function public.admin_operator_upsert_fare_rule(
uuid,uuid,text,numeric,numeric,numeric,numeric,numeric,numeric,boolean) to authenticated,service_role;
