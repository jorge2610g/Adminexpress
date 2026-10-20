-- Suscripciones: planes, montos y pagos de la zona asignada.
-- Nunca devuelve credenciales ni provider_data/qr_payload de la pasarela.
create or replace function public.admin_operator_subscription_overview(p_zone_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public'
as $subs$
declare v_zone uuid;v_key text;v_currency text;v_name text;
begin
 perform public.admin_operator_assert_module('subscriptions');
 v_zone:=public.admin_effective_zone_id(p_zone_id);
 select z.zone_key,z.currency_code,z.name into v_key,v_currency,v_name
 from public.service_zones z where z.id=v_zone and z.active=true;
 if v_key is null then raise exception 'Zona inactiva';end if;
 return jsonb_build_object(
  'zone_id',v_zone,'zone_key',v_key,'zone_name',v_name,'currency_code',v_currency,
  'plans',coalesce((
     select jsonb_agg(to_jsonb(p) order by p.sort_order,p.name)
     from public.driver_subscription_plans p where p.zone_key=v_key
  ),'[]'::jsonb),
  'payments',coalesce((
     select jsonb_agg(to_jsonb(x) order by x.created_at desc)
     from (select sp.id,sp.driver_id,sp.plan_id,sp.amount,sp.currency_code,
                  sp.status,sp.provider,sp.created_at,sp.paid_at
           from public.driver_subscription_payments sp
           where sp.zone_key=v_key
           order by sp.created_at desc limit 100) x
  ),'[]'::jsonb),
  'enabled',coalesce((select s.enabled from public.driver_subscription_zone_settings s
       where s.zone_id=v_zone),false),
  'enforce_access',coalesce((select s.enforce_access from public.driver_subscription_zone_settings s
       where s.zone_id=v_zone),false)
 );
end
$subs$;

create or replace function public.admin_operator_upsert_subscription_plan(
 p_id bigint,p_zone_id uuid,p_code text,p_name text,p_amount numeric,
 p_days integer,p_benefits jsonb,p_active boolean,p_sort_order integer
) returns bigint language plpgsql security definer set search_path='public'
as $subs$
declare v_zone uuid;v_key text;v_currency text;v_code text;v_id bigint;
begin
 perform public.admin_operator_assert_module('subscriptions');
 v_zone:=public.admin_effective_zone_id(p_zone_id);
 select z.zone_key,z.currency_code into v_key,v_currency
 from public.service_zones z where z.id=v_zone and z.active=true;
 if v_key is null then raise exception 'Zona inactiva';end if;
 v_code:=lower(trim(coalesce(p_code,'')));
 if v_code !~ '^[a-z][a-z0-9_]{1,39}$' then raise exception 'Codigo invalido';end if;
 if nullif(trim(coalesce(p_name,'')),'') is null then raise exception 'Nombre requerido';end if;
 if p_amount is null or p_amount<0 then raise exception 'Monto invalido';end if;
 if p_days is null or p_days<1 or p_days>3650 then raise exception 'Duracion invalida';end if;
 if jsonb_typeof(coalesce(p_benefits,'[]'::jsonb))<>'array' then
   raise exception 'Beneficios invalidos';end if;
 if p_id is not null and not exists(
   select 1 from public.driver_subscription_plans p
   where p.id=p_id and p.zone_key=v_key
 ) then raise exception 'Plan de otra zona o inexistente';end if;
 if p_id is null then
   insert into public.driver_subscription_plans
   (zone_key,currency_code,code,name,amount,days,benefits,active,sort_order,updated_at)
   values(v_key,v_currency,v_code,trim(p_name),p_amount,p_days,
          coalesce(p_benefits,'[]'::jsonb),coalesce(p_active,true),coalesce(p_sort_order,100),now())
   returning id into v_id;
 else
   update public.driver_subscription_plans
   set code=v_code,name=trim(p_name),amount=p_amount,days=p_days,currency_code=v_currency,
       benefits=coalesce(p_benefits,'[]'::jsonb),active=coalesce(p_active,true),
       sort_order=coalesce(p_sort_order,100),updated_at=now()
   where id=p_id and zone_key=v_key returning id into v_id;
 end if;
 if v_id is null then raise exception 'Plan no guardado';end if;
 insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,details)
 values(auth.uid(),'operator_subscription_plan_upsert','driver_subscription_plans',v_id::text,
        jsonb_build_object('zone_id',v_zone,'amount',p_amount,'currency',v_currency));
 return v_id;
end
$subs$;

revoke all on function public.admin_operator_subscription_overview(uuid) from public,anon;
revoke all on function public.admin_operator_upsert_subscription_plan(bigint,uuid,text,text,numeric,integer,jsonb,boolean,integer) from public,anon;
grant execute on function public.admin_operator_subscription_overview(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_upsert_subscription_plan(bigint,uuid,text,text,numeric,integer,jsonb,boolean,integer) to authenticated,service_role;
