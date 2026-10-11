-- Reproducible record of migrations already APPLIED only to Express Preview.
-- THIS IS NOT AN AUTOMATIC PRODUCTION MIGRATION.
-- Preview project: xbphilqezmwfjfpdbwad. Never run against Production.
-- Source of table shape: Expressdelivery 20261009165500_shared_distance_steps.sql.
create table if not exists public.zone_distance_fare_steps (
  zone_id uuid not null references public.service_zones(id) on delete cascade,
  service_key text not null,
  up_to_km numeric(9,2) not null check (up_to_km > 0),
  fare numeric(12,2) not null check (fare > 0),
  primary key (zone_id, service_key, up_to_km)
);
create index if not exists zone_distance_fare_steps_lookup
  on public.zone_distance_fare_steps(zone_id, service_key, up_to_km);
alter table public.zone_distance_fare_steps enable row level security;
revoke all on public.zone_distance_fare_steps from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_distance_fare_steps_get(p_zone_id uuid, p_service_key text, p_channel text DEFAULT 'preview'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null or not public.is_admin()
  or p_channel <> 'preview'
  or not public.admin_environment_allowed('preview') then
    raise exception 'Acceso no autorizado a tarifas Preview';
 end if;
 return jsonb_build_object(
  'zone_id',p_zone_id,'service_key',p_service_key,
  'currency',(select currency_code from public.service_zones where id=p_zone_id),
  'steps',(select coalesce(jsonb_agg(jsonb_build_object(
     'up_to_km',up_to_km,'fare',fare) order by up_to_km),'[]'::jsonb)
   from public.zone_distance_fare_steps
   where zone_id=p_zone_id and service_key=p_service_key)
 );
end $function$;

CREATE OR REPLACE FUNCTION public.admin_distance_fare_steps_replace(p_zone_id uuid, p_service_key text, p_steps jsonb, p_channel text DEFAULT 'preview'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_step jsonb; v_km numeric; v_fare numeric;
  v_prev_km numeric:=0; v_prev_fare numeric:=0;
begin
 if auth.uid() is null or not public.is_admin()
  or p_channel <> 'preview'
  or not public.admin_environment_allowed('preview') then
    raise exception 'Acceso no autorizado a tarifas Preview';
 end if;
 if not exists (select 1 from public.service_zones z where z.id=p_zone_id)
  or not exists(select 1 from public.zone_service_catalog z
    where z.zone_id=p_zone_id and z.service_key=p_service_key) then
    raise exception 'La zona o servicio no existe en Preview';
 end if;
 if p_steps is null or jsonb_typeof(p_steps)<>'array'
  or jsonb_array_length(p_steps)>100 then
    raise exception 'Ingresa una lista de hasta 100 escalones';
 end if;
 for v_step in select value from jsonb_array_elements(p_steps) loop
   if jsonb_typeof(v_step)<>'object'
      or (v_step->>'up_to_km') is null or (v_step->>'fare') is null then
     raise exception 'Escalón inválido';
   end if;
   begin
     v_km:=(v_step->>'up_to_km')::numeric;
     v_fare:=(v_step->>'fare')::numeric;
   exception when others then
     raise exception 'Distancia y tarifa deben ser numéricas';
   end;
   if v_km<=v_prev_km or v_fare<=0 or v_fare<v_prev_fare
     or v_km>10000 or v_fare>100000000 then
     raise exception 'Las distancias deben subir y el precio no puede bajar';
   end if;
   v_prev_km:=v_km; v_prev_fare:=v_fare;
 end loop;
 delete from public.zone_distance_fare_steps
   where zone_id=p_zone_id and service_key=p_service_key;
 for v_step in select value from jsonb_array_elements(p_steps) loop
   insert into public.zone_distance_fare_steps(zone_id,service_key,up_to_km,fare)
     values(p_zone_id,p_service_key,(v_step->>'up_to_km')::numeric,
       (v_step->>'fare')::numeric);
 end loop;
 return public.admin_distance_fare_steps_get(p_zone_id,p_service_key,'preview');
end $function$;

revoke all on function public.admin_distance_fare_steps_get(uuid,text,text)
  from public, anon;
revoke all on function public.admin_distance_fare_steps_replace(uuid,text,jsonb,text)
  from public, anon;
grant execute on function public.admin_distance_fare_steps_get(uuid,text,text)
  to authenticated;
grant execute on function public.admin_distance_fare_steps_replace(uuid,text,jsonb,text)
  to authenticated;
