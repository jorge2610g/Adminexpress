-- Zone-scoped debt management and manual wallet adjustments for Adminexpress.
-- Every financial write is authenticated, permission checked and append-audited.

create table if not exists public.admin_financial_adjustment_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  zone_id uuid not null references public.service_zones(id),
  channel text not null check (channel in ('preview','production')),
  country_code text not null,
  currency_code text not null,
  target_role text not null check (target_role in ('passenger','driver')),
  action_type text not null check (action_type in ('manual_debt_settlement','wallet_adjustment')),
  amount numeric(14,2) not null,
  balance_before numeric(14,2),
  balance_after numeric(14,2),
  payment_method text,
  payment_reference text,
  related_debt_ids uuid[] not null default '{}',
  reason text not null,
  actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists admin_financial_adjustment_audit_zone_created_idx
  on public.admin_financial_adjustment_audit(zone_id,channel,created_at desc);
create index if not exists admin_financial_adjustment_audit_user_created_idx
  on public.admin_financial_adjustment_audit(user_id,channel,created_at desc);
alter table public.admin_financial_adjustment_audit enable row level security;
revoke all on public.admin_financial_adjustment_audit from public,anon,authenticated;

create or replace function public.admin_financial_assert_scope(
  p_channel text,p_zone_id uuid,p_write boolean default false
) returns uuid
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_channel text;
  v_zone uuid;
  v_context jsonb;
  v_role text;
begin
  v_channel:=public.admin_assert_environment(p_channel);
  if public.admin_current_runtime_environment() is distinct from v_channel then
    raise exception 'El contexto administrativo cambió; vuelve a cargar el panel';
  end if;
  v_context:=public.admin_access_context();
  v_role:=v_context->>'role';
  if coalesce((v_context->>'allowed')::boolean,false) is not true then
    raise exception 'No autorizado';
  end if;
  if v_role<>'operator' and not (
    coalesce(v_context->'allowed_modules','[]'::jsonb) ? 'payments' or
    coalesce(v_context->'allowed_modules','[]'::jsonb) ? '*'
  ) then
    raise exception 'El módulo de pagos no está autorizado';
  end if;
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  if not exists(select 1 from public.service_zones z where z.id=v_zone) then
    raise exception 'Zona no encontrada';
  end if;
  if v_role='operator' then
    perform public.admin_operator_assert_module('payments');
    if v_channel<>'production' then
      raise exception 'Los operadores solo pueden operar Producción';
    end if;
  elsif v_role='zone_monitor' and p_write then
    raise exception 'El monitor de zona tiene acceso de solo lectura';
  elsif v_role not in ('super_admin','zone_monitor') then
    raise exception 'No autorizado';
  end if;
  if p_write and v_context->>'read_only'='true' then
    raise exception 'El acceso es de solo lectura';
  end if;
  return v_zone;
end
$function$;
revoke all on function public.admin_financial_assert_scope(text,uuid,boolean)
  from public,anon,authenticated;
grant execute on function public.admin_financial_assert_scope(text,uuid,boolean)
  to authenticated,service_role;

create or replace function public.admin_debt_wallet_list_v1(
  p_channel text,
  p_zone_id uuid,
  p_search text default null,
  p_target_role text default null,
  p_limit integer default 100,
  p_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_channel text;
  v_zone uuid;
  v_country text;
  v_currency text;
  v_search text:=nullif(trim(coalesce(p_search,'')),'');
  v_rows jsonb;
begin
  v_channel:=public.admin_assert_environment(p_channel);
  v_zone:=public.admin_financial_assert_scope(v_channel,p_zone_id,false);
  if p_target_role is not null and p_target_role not in ('passenger','driver') then
    raise exception 'Tipo de cuenta inválido';
  end if;
  select z.country_code,z.currency_code into v_country,v_currency
  from public.service_zones z where z.id=v_zone;
  if v_country is null or v_currency is null then raise exception 'Zona no disponible'; end if;

  with targets as (
    select u.id as user_id,u.full_name,u.phone,'passenger'::text as target_role,
      z.id as zone_id,z.name as zone_name,z.country_code,z.currency_code
    from public.users u
    join public.service_zones z on z.id=v_zone
    where z.id=v_zone
      and (p_target_role is null or p_target_role='passenger')
      and (u.last_zone_id=z.id or exists(select 1 from public.cancellation_fee_debts dx
        where dx.user_id=u.id and dx.zone_id=z.id and dx.channel=v_channel
          and dx.role='passenger'))
      and ((v_channel='preview' and public.is_active_audit_user(u.id)) or
           (v_channel='production' and not public.is_active_audit_user(u.id)))
      and (v_search is null or u.full_name ilike '%'||v_search||'%' or u.phone ilike '%'||v_search||'%')
    union all
    select u.id,u.full_name,u.phone,'driver'::text,
      z.id,z.name,z.country_code,z.currency_code
    from public.driver_profiles dp
    join public.users u on u.id=dp.id
    join public.service_zones z on z.id=dp.zone_id
    where z.id=v_zone
      and (p_target_role is null or p_target_role='driver')
      and ((v_channel='preview' and public.is_active_audit_user(u.id)) or
           (v_channel='production' and not public.is_active_audit_user(u.id)))
      and (v_search is null or u.full_name ilike '%'||v_search||'%' or u.phone ilike '%'||v_search||'%')
  ), page as (
    select t.* from targets t
    order by lower(coalesce(t.full_name,'')),t.user_id,t.target_role
    limit greatest(1,least(coalesce(p_limit,100),200))
    offset greatest(coalesce(p_offset,0),0)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id',p.user_id,'full_name',p.full_name,'phone',p.phone,
    'target_role',p.target_role,'zone_id',p.zone_id,'zone_name',p.zone_name,
    'country_code',p.country_code,'currency_code',p.currency_code,
    'balance',coalesce((select w.balance from public.wallet_country_accounts w
      where w.user_id=p.user_id and w.country_code=p.country_code and w.channel=v_channel),0),
    'open_debt_total',coalesce((select sum(d.amount) from public.cancellation_fee_debts d
      where d.user_id=p.user_id and d.zone_id=p.zone_id and d.channel=v_channel
        and d.role=p.target_role and d.country_code=p.country_code and d.paid_at is null),0),
    'open_debt_count',(select count(*) from public.cancellation_fee_debts d
      where d.user_id=p.user_id and d.zone_id=p.zone_id and d.channel=v_channel
        and d.role=p.target_role and d.country_code=p.country_code and d.paid_at is null)
  ) order by lower(coalesce(p.full_name,'')),p.target_role),'[]'::jsonb)
  into v_rows from page p;

  return jsonb_build_object('zone_id',v_zone,'channel',v_channel,
    'country_code',v_country,'currency_code',v_currency,'users',v_rows);
end
$function$;

create or replace function public.admin_debt_wallet_detail_v1(
  p_channel text,p_zone_id uuid,p_user_id uuid,p_target_role text
) returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_channel text;
  v_zone uuid;
  v_user public.users%rowtype;
  v_country text;
  v_currency text;
  v_balance numeric:=0;
  v_debts jsonb;
  v_movements jsonb;
  v_audit jsonb;
  v_target_found boolean:=false;
begin
  v_channel:=public.admin_assert_environment(p_channel);
  v_zone:=public.admin_financial_assert_scope(v_channel,p_zone_id,false);
  if p_user_id is null or p_target_role is null
     or p_target_role not in ('passenger','driver') then
    raise exception 'Cuenta o tipo de perfil inválido';
  end if;
  select * into v_user from public.users u where u.id=p_user_id;
  if not found then raise exception 'Cuenta no encontrada'; end if;
  if (v_channel='preview' and not public.is_active_audit_user(p_user_id)) or
     (v_channel='production' and public.is_active_audit_user(p_user_id)) then
    raise exception 'La cuenta pertenece a otro entorno';
  end if;

  if p_target_role='driver' then
    select z.country_code,z.currency_code into v_country,v_currency
    from public.driver_profiles dp join public.service_zones z on z.id=dp.zone_id
    where dp.id=p_user_id and z.id=v_zone;
    v_target_found:=found;
  else
    select z.country_code,z.currency_code into v_country,v_currency
    from public.users u join public.service_zones z on z.id=v_zone
    where u.id=p_user_id and (u.last_zone_id=z.id
       or exists(select 1 from public.cancellation_fee_debts dx
         join public.service_zones dz on dz.id=dx.zone_id
         where dx.user_id=u.id and dx.zone_id=v_zone and dx.channel=v_channel
           and dx.role='passenger' and dz.id=v_zone));
    v_target_found:=found;
  end if;
  if not v_target_found then raise exception 'La cuenta no pertenece a la zona autorizada'; end if;
  perform public.admin_assert_target_environment(p_user_id,v_channel);

  select coalesce(w.balance,0) into v_balance from public.wallet_country_accounts w
    where w.user_id=p_user_id and w.country_code=v_country and w.channel=v_channel;
  v_balance:=coalesce(v_balance,0);
  select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc),'[]'::jsonb)
    into v_debts from public.cancellation_fee_debts d
    where d.user_id=p_user_id and d.zone_id=v_zone and d.channel=v_channel
      and d.country_code=v_country and d.role=p_target_role;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',t.id,'amount',t.amount,'type',t.type,'status',t.status,
      'reference',t.reference,'created_at',t.created_at,'country_code',t.country_code
    ) order by t.created_at desc),'[]'::jsonb)
    into v_movements from (
      select * from public.wallet_transactions
      where user_id=p_user_id and channel=v_channel and country_code=v_country
      order by created_at desc limit 50
    ) t;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',a.id,'action_type',a.action_type,'amount',a.amount,
      'currency_code',a.currency_code,'payment_method',a.payment_method,
      'payment_reference',a.payment_reference,'related_debt_ids',a.related_debt_ids,
      'reason',a.reason,'actor_id',a.actor_id,'created_at',a.created_at,
      'balance_before',a.balance_before,'balance_after',a.balance_after
    ) order by a.created_at desc),'[]'::jsonb)
    into v_audit from (
      select * from public.admin_financial_adjustment_audit
      where user_id=p_user_id and zone_id=v_zone and channel=v_channel
        and target_role=p_target_role
      order by created_at desc limit 50
    ) a;

  return jsonb_build_object('user_id',p_user_id,'full_name',v_user.full_name,
    'phone',v_user.phone,'target_role',p_target_role,'zone_id',v_zone,
    'country_code',v_country,'currency_code',v_currency,'balance',v_balance,
    'debts',v_debts,'wallet_movements',v_movements,'audit',v_audit);
end
$function$;

create or replace function public.admin_settle_cancellation_debts_manual_v1(
  p_channel text,p_zone_id uuid,p_user_id uuid,p_target_role text,
  p_debt_ids uuid[],p_payment_method text,p_payment_reference text,p_reason text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_channel text;
  v_zone uuid;
  v_country text;
  v_currency text;
  v_count integer;
  v_amount numeric;
  v_ids uuid[];
begin
  v_channel:=public.admin_assert_environment(p_channel);
  v_zone:=public.admin_financial_assert_scope(v_channel,p_zone_id,true);
  if p_user_id is null or p_target_role not in ('passenger','driver') then
    raise exception 'Cuenta o tipo de perfil inválido';
  end if;
  if p_payment_method is null or p_payment_method not in ('cash','bank_transfer','other') then
    raise exception 'Método de pago manual inválido';
  end if;
  if length(trim(coalesce(p_payment_reference,'')))>200 then
    raise exception 'La referencia no puede superar 200 caracteres';
  end if;
  if length(trim(coalesce(p_reason,'')))<5 or length(trim(p_reason))>500 then
    raise exception 'Indica un motivo de al menos 5 caracteres';
  end if;
  if coalesce(cardinality(p_debt_ids),0)<1 or cardinality(p_debt_ids)>50 then
    raise exception 'Selecciona entre 1 y 50 deudas';
  end if;
  select z.country_code,z.currency_code into v_country,v_currency
  from public.service_zones z where z.id=v_zone;
  if p_target_role='driver' then
    perform 1 from public.driver_profiles dp where dp.id=p_user_id and dp.zone_id=v_zone;
  else
    perform 1 from public.users u where u.id=p_user_id and
      (u.last_zone_id=v_zone or exists(select 1 from public.cancellation_fee_debts d
        where d.user_id=u.id and d.zone_id=v_zone and d.channel=v_channel
          and d.role='passenger'));
  end if;
  if not found then raise exception 'La cuenta no pertenece a la zona autorizada'; end if;
  perform public.admin_assert_target_environment(p_user_id,v_channel);
  if (v_channel='preview' and not public.is_active_audit_user(p_user_id)) or
     (v_channel='production' and public.is_active_audit_user(p_user_id)) then
    raise exception 'La cuenta pertenece a otro entorno';
  end if;
  select coalesce(array_agg(distinct x order by x),'{}'::uuid[]) into v_ids
  from unnest(p_debt_ids) x;
  if cardinality(v_ids)<>cardinality(p_debt_ids) then
    raise exception 'La selección contiene deudas duplicadas';
  end if;
  perform 1 from public.cancellation_fee_debts d
    where d.id=any(v_ids) and d.user_id=p_user_id and d.zone_id=v_zone
      and d.channel=v_channel and d.country_code=v_country
      and d.role=p_target_role and d.paid_at is null for update;
  select count(*),coalesce(sum(d.amount),0) into v_count,v_amount
    from public.cancellation_fee_debts d
    where d.id=any(v_ids) and d.user_id=p_user_id and d.zone_id=v_zone
      and d.channel=v_channel and d.country_code=v_country
      and d.role=p_target_role and d.paid_at is null;
  if v_count<>cardinality(v_ids) or v_amount<=0 then
    raise exception 'Una o más deudas ya se liquidaron o no pertenecen a esta cuenta';
  end if;
  update public.cancellation_fee_debts d
    set paid_at=now()
    where d.id=any(v_ids) and d.user_id=p_user_id and d.zone_id=v_zone
      and d.channel=v_channel and d.country_code=v_country
      and d.role=p_target_role and d.paid_at is null;
  insert into public.admin_financial_adjustment_audit(
    user_id,zone_id,channel,country_code,currency_code,target_role,
    action_type,amount,payment_method,payment_reference,related_debt_ids,
    reason,actor_id
  ) values (
    p_user_id,v_zone,v_channel,v_country,upper(v_currency),p_target_role,
    'manual_debt_settlement',v_amount,p_payment_method,
    nullif(trim(coalesce(p_payment_reference,'')),''),v_ids,
    trim(p_reason),auth.uid()
  );
  insert into public.notifications(user_id,title,body,type,metadata,channel)
    values(p_user_id,'Pago de deuda registrado',
      'Se registró manualmente el pago de tu deuda por cancelación.',
      'cancellation_fee_paid',jsonb_build_object(
        'zone_id',v_zone,'currency_code',upper(v_currency),
        'amount',v_amount,'manual',true,'channel',v_channel
      ),v_channel);
  return jsonb_build_object('settled',true,'amount',v_amount,
    'currency_code',upper(v_currency),'debt_count',v_count,'debt_ids',v_ids);
end
$function$;

create or replace function public.admin_adjust_wallet_balance_v1(
  p_channel text,p_zone_id uuid,p_user_id uuid,p_target_role text,
  p_delta numeric,p_reason text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_channel text;
  v_zone uuid;
  v_country text;
  v_currency text;
  v_unit numeric;
  v_before numeric:=0;
  v_after numeric;
begin
  v_channel:=public.admin_assert_environment(p_channel);
  v_zone:=public.admin_financial_assert_scope(v_channel,p_zone_id,true);
  if p_user_id is null or p_target_role not in ('passenger','driver') then
    raise exception 'Cuenta o tipo de perfil inválido';
  end if;
  if p_delta is null or p_delta=0 or abs(p_delta)>500000 then
    raise exception 'El ajuste debe estar entre 0.01 y 500.000';
  end if;
  if length(trim(coalesce(p_reason,'')))<5 or length(trim(p_reason))>500 then
    raise exception 'Indica un motivo de al menos 5 caracteres';
  end if;
  select z.country_code,z.currency_code into v_country,v_currency
  from public.service_zones z where z.id=v_zone;
  if p_target_role='driver' then
    perform 1 from public.driver_profiles dp where dp.id=p_user_id and dp.zone_id=v_zone;
  else
    perform 1 from public.users u where u.id=p_user_id and
      (u.last_zone_id=v_zone or exists(select 1 from public.cancellation_fee_debts d
        where d.user_id=u.id and d.zone_id=v_zone and d.channel=v_channel
          and d.role='passenger'));
  end if;
  if not found then raise exception 'La cuenta no pertenece a la zona autorizada'; end if;
  perform public.admin_assert_target_environment(p_user_id,v_channel);
  if (v_channel='preview' and not public.is_active_audit_user(p_user_id)) or
     (v_channel='production' and public.is_active_audit_user(p_user_id)) then
    raise exception 'La cuenta pertenece a otro entorno';
  end if;
  v_unit:=case when upper(v_currency)='CLP' then 1 else 0.01 end;
  if mod(abs(p_delta),v_unit)<>0 then
    raise exception 'El ajuste no respeta la unidad mínima de %',upper(v_currency);
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'admin-wallet-adjustment:'||p_user_id::text||':'||v_country||':'||v_channel,0));
  select coalesce(w.balance,0) into v_before from public.wallet_country_accounts w
    where w.user_id=p_user_id and w.country_code=v_country and w.channel=v_channel
    for update;
  v_before:=coalesce(v_before,0);
  v_after:=v_before+p_delta;
  if v_after<0 then raise exception 'El ajuste no puede dejar saldo negativo'; end if;
  insert into public.wallet_transactions(
    user_id,amount,type,status,reference,country_code,channel
  ) values (
    p_user_id,p_delta,'adjustment','completed',
    'Ajuste administrativo: '||left(trim(p_reason),350),v_country,v_channel
  );
  if v_channel='production' then
    perform public.mirror_legacy_wallet_delta(p_user_id,upper(v_currency),p_delta);
  end if;
  insert into public.admin_financial_adjustment_audit(
    user_id,zone_id,channel,country_code,currency_code,target_role,
    action_type,amount,balance_before,balance_after,reason,actor_id
  ) values (
    p_user_id,v_zone,v_channel,v_country,upper(v_currency),p_target_role,
    'wallet_adjustment',p_delta,v_before,v_after,trim(p_reason),auth.uid()
  );
  insert into public.notifications(user_id,title,body,type,metadata,channel)
    values(p_user_id,'Saldo actualizado',
      'Se realizó un ajuste administrativo de '||upper(v_currency)||' '||
        trim(to_char(p_delta,'FM999999990.00'))||'. Motivo: '||left(trim(p_reason),240),
      'wallet_adjustment',jsonb_build_object(
        'zone_id',v_zone,'currency_code',upper(v_currency),
        'amount',p_delta,'channel',v_channel
      ),v_channel);
  return jsonb_build_object('adjusted',true,'delta',p_delta,
    'balance_before',v_before,'balance_after',v_after,
    'currency_code',upper(v_currency));
end
$function$;

revoke all on function public.admin_debt_wallet_list_v1(text,uuid,text,text,integer,integer)
  from public,anon;
revoke all on function public.admin_debt_wallet_detail_v1(text,uuid,uuid,text)
  from public,anon;
revoke all on function public.admin_settle_cancellation_debts_manual_v1(text,uuid,uuid,text,uuid[],text,text,text)
  from public,anon;
revoke all on function public.admin_adjust_wallet_balance_v1(text,uuid,uuid,text,numeric,text)
  from public,anon;
grant execute on function public.admin_debt_wallet_list_v1(text,uuid,text,text,integer,integer)
  to authenticated,service_role;
grant execute on function public.admin_debt_wallet_detail_v1(text,uuid,uuid,text)
  to authenticated,service_role;
grant execute on function public.admin_settle_cancellation_debts_manual_v1(text,uuid,uuid,text,uuid[],text,text,text)
  to authenticated,service_role;
grant execute on function public.admin_adjust_wallet_balance_v1(text,uuid,uuid,text,numeric,text)
  to authenticated,service_role;
