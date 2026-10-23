-- Track the payable portion of administrative wallet debits separately from
-- commission balances and cancellation fees. A verified wallet credit pays
-- these debts FIFO; the original adjustment remains in the financial audit.
alter table public.admin_financial_operations
  add column if not exists admin_adjustment_debt_id uuid;

create table if not exists public.admin_wallet_adjustment_debts (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null unique
    references public.admin_financial_operations(id) on delete restrict,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('passenger','driver')),
  zone_id uuid not null references public.service_zones(id),
  channel text not null check (channel in ('preview','production')),
  country_code text not null,
  currency_code text not null,
  amount numeric not null check (amount > 0),
  remaining_amount numeric not null check (remaining_amount >= 0),
  reason text not null check (length(trim(reason)) between 3 and 500),
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  constraint admin_wallet_adjustment_debts_state_check
    check ((remaining_amount=0 and paid_at is not null)
        or (remaining_amount>0 and paid_at is null))
);
create index if not exists admin_wallet_adjustment_debts_open_user_idx
  on public.admin_wallet_adjustment_debts(user_id,channel,country_code,created_at)
  where remaining_amount>0;
create index if not exists admin_wallet_adjustment_debts_zone_idx
  on public.admin_wallet_adjustment_debts(zone_id,channel,created_at desc);
alter table public.admin_wallet_adjustment_debts enable row level security;
revoke all on public.admin_wallet_adjustment_debts from public,anon,authenticated;

alter table public.admin_financial_operations
  add constraint admin_financial_operations_adjustment_debt_id_uq
  unique(admin_adjustment_debt_id);
alter table public.admin_financial_operations
  add constraint admin_financial_operations_adjustment_debt_fk
  foreign key(admin_adjustment_debt_id)
  references public.admin_wallet_adjustment_debts(id) on delete restrict;

create or replace function public.apply_admin_adjustment_debt_credit(
  p_user_id uuid,p_country_code text,p_channel text,p_amount numeric
) returns numeric
language plpgsql security definer set search_path=''
as $fn$
declare
  v_left numeric:=greatest(0,coalesce(p_amount,0));
  v_apply numeric;
  v_debt record;
begin
  if v_left=0 then return 0; end if;
  for v_debt in
    select d.id,d.remaining_amount
    from public.admin_wallet_adjustment_debts d
    where d.user_id=p_user_id and d.country_code=upper(p_country_code)
      and d.channel=p_channel and d.remaining_amount>0
    order by d.created_at,d.id
    for update
  loop
    exit when v_left<=0;
    v_apply:=least(v_left,v_debt.remaining_amount);
    update public.admin_wallet_adjustment_debts
      set remaining_amount=remaining_amount-v_apply,
          paid_at=case when remaining_amount-v_apply=0 then now() else null end
      where id=v_debt.id;
    v_left:=v_left-v_apply;
  end loop;
  return greatest(0,coalesce(p_amount,0))-v_left;
end;
$fn$;
revoke all on function public.apply_admin_adjustment_debt_credit(uuid,text,text,numeric)
  from public,anon,authenticated;

-- Extend the existing zonal debt RPC with the distinct administrative-debt
-- stream. The caller already applies the zone, role, module and account scope.
create or replace function public.admin_finance_adjustment_debts_v1(
  p_zone_id uuid,p_status text default 'pending',p_role text default 'all',
  p_search text default null,p_limit integer default 200
) returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_channel text;
  v_zone uuid;
  v_role text;
  v_country text;
  v_status text:=lower(trim(coalesce(p_status,'pending')));
  v_role_filter text:=lower(trim(coalesce(p_role,'all')));
  v_search text:=nullif(trim(coalesce(p_search,'')),'');
  v_rows jsonb;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if coalesce(v_role,'') not in ('super_admin','operator') then
    raise exception 'No autorizado para consultar deudas';
  end if;
  if v_role='operator' then perform public.admin_operator_assert_module('payments'); end if;
  v_channel:=public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  if v_status not in ('pending','settled','all') then raise exception 'Filtro de deuda inválido'; end if;
  if v_role_filter not in ('all','passenger','driver') then raise exception 'Filtro de usuario inválido'; end if;
  select country_code into v_country from public.service_zones where id=v_zone;
  if v_country is null then raise exception 'Zona no encontrada'; end if;
  select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.created_at desc),'[]'::jsonb)
    into v_rows
  from (
    select d.id as debt_id,d.user_id,null::uuid as trip_id,d.zone_id,d.role,
      d.remaining_amount as amount,d.currency_code,d.country_code,d.reason,
      d.created_at,d.paid_at,
      case when d.paid_at is null then 'pending' else 'settled' end as status,
      'admin_adjustment'::text as debt_type,u.full_name,u.phone,au.email,
      coalesce(o.reason,'') as resolution_reason,o.created_at as resolved_at,
      actor.full_name as resolved_by_name
    from public.admin_wallet_adjustment_debts d
    join public.users u on u.id=d.user_id
    left join auth.users au on au.id=u.id
    left join public.admin_financial_operations o
      on o.admin_adjustment_debt_id=d.id and o.operation_type='debt_settlement'
    left join public.users actor on actor.id=o.actor_id
    where d.zone_id=v_zone and d.channel=v_channel and d.country_code=v_country
      and (v_status='all' or (v_status='pending' and d.paid_at is null)
        or (v_status='settled' and d.paid_at is not null))
      and (v_role_filter='all' or d.role=v_role_filter)
      and (v_channel<>'preview' or public.is_active_audit_user(d.user_id))
      and (v_channel<>'production' or not public.is_active_audit_user(d.user_id))
      and (v_search is null or u.full_name ilike '%'||v_search||'%'
        or coalesce(u.phone,'') ilike '%'||v_search||'%'
        or coalesce(au.email,'') ilike '%'||v_search||'%'
        or d.reason ilike '%'||v_search||'%')
    order by d.created_at desc limit greatest(1,least(coalesce(p_limit,200),500))
  ) row_data;
  return jsonb_build_object('channel',v_channel,'zone_id',v_zone,
    'country_code',v_country,'debts',v_rows);
end;
$fn$;
revoke all on function public.admin_finance_adjustment_debts_v1(uuid,text,text,text,integer)
  from public,anon;
grant execute on function public.admin_finance_adjustment_debts_v1(uuid,text,text,text,integer)
  to authenticated;

create or replace function public.admin_finance_settle_adjustment_debt_v1(
  p_zone_id uuid,p_debt_id uuid,p_reason text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare
  v_channel text;
  v_zone uuid;
  v_role text;
  v_debt public.admin_wallet_adjustment_debts%rowtype;
  v_existing public.admin_financial_operations%rowtype;
  v_tx uuid;
  v_balance numeric:=0;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if coalesce(v_role,'') not in ('super_admin','operator') then raise exception 'No autorizado para liquidar deudas'; end if;
  if v_role='operator' then perform public.admin_operator_assert_module('payments'); end if;
  v_channel:=public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  if p_idempotency_key is null then raise exception 'Falta la clave de operación'; end if;
  if length(trim(coalesce(p_reason,''))) not between 3 and 500 then
    raise exception 'Indica un motivo de 3 a 500 caracteres';
  end if;
  select * into v_existing from public.admin_financial_operations o
    where o.actor_id=auth.uid() and o.channel=v_channel
      and o.idempotency_key=p_idempotency_key;
  if found then
    if v_existing.operation_type<>'debt_settlement'
       or v_existing.admin_adjustment_debt_id is distinct from p_debt_id
       or v_existing.zone_id is distinct from v_zone
       or v_existing.reason is distinct from trim(p_reason) then
      raise exception 'La clave de operación ya se usó con otros datos';
    end if;
    return jsonb_build_object('ok',true,'already_processed',true,
      'operation_id',v_existing.id);
  end if;
  select * into v_debt from public.admin_wallet_adjustment_debts d
    where d.id=p_debt_id and d.zone_id=v_zone and d.channel=v_channel for update;
  if not found or v_debt.remaining_amount<=0 then raise exception 'Deuda no encontrada o ya liquidada'; end if;
  if (v_channel='preview' and not public.is_active_audit_user(v_debt.user_id))
     or (v_channel='production' and public.is_active_audit_user(v_debt.user_id)) then
    raise exception 'La deuda pertenece a otro entorno';
  end if;
  select coalesce(balance,0) into v_balance from public.wallet_country_accounts
    where user_id=v_debt.user_id and country_code=v_debt.country_code
      and channel=v_channel for update;
  v_balance:=coalesce(v_balance,0);
  insert into public.wallet_transactions(user_id,amount,type,status,reference,country_code,channel)
    values(v_debt.user_id,v_debt.remaining_amount,'adjustment','completed',
      'Liquidación manual de ajuste: '||trim(p_reason),v_debt.country_code,v_channel)
    returning id into v_tx;
  if v_channel='production' then
    perform public.mirror_legacy_wallet_delta(v_debt.user_id,v_debt.currency_code,v_debt.remaining_amount);
  end if;
  update public.admin_wallet_adjustment_debts
    set remaining_amount=0,paid_at=now() where id=v_debt.id;
  insert into public.admin_financial_operations(
    operation_type,actor_id,target_user_id,target_role,zone_id,channel,
    country_code,currency_code,amount,balance_before,balance_after,
    wallet_transaction_id,admin_adjustment_debt_id,reason,idempotency_key
  ) values (
    'debt_settlement',auth.uid(),v_debt.user_id,v_debt.role,v_zone,v_channel,
    v_debt.country_code,v_debt.currency_code,v_debt.remaining_amount,
    v_balance,v_balance+v_debt.remaining_amount,v_tx,v_debt.id,
    trim(p_reason),p_idempotency_key
  ) returning * into v_existing;
  return jsonb_build_object('ok',true,'already_processed',false,
    'operation_id',v_existing.id,'amount',v_debt.remaining_amount,
    'currency_code',v_debt.currency_code);
end;
$fn$;
revoke all on function public.admin_finance_settle_adjustment_debt_v1(uuid,uuid,text,uuid)
  from public,anon;
grant execute on function public.admin_finance_settle_adjustment_debt_v1(uuid,uuid,text,uuid)
  to authenticated;

-- Keep the existing role/module/zone/channel/idempotency rules and make the
-- uncovered overdraft a distinct debt. Credits pay those debts FIFO.
create or replace function public.admin_finance_adjust_wallet_v1(
  p_zone_id uuid,p_user_id uuid,p_direction text,p_amount numeric,
  p_reason text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare
  v_channel text; v_zone uuid; v_role text; v_target_role text;
  v_target_zone uuid; v_country text; v_currency text; v_delta numeric;
  v_before numeric:=0; v_after numeric; v_debt_amount numeric:=0;
  v_account public.wallet_country_accounts%rowtype;
  v_legacy public.wallet_accounts%rowtype;
  v_tx uuid; v_operation public.admin_financial_operations%rowtype;
  v_debt_id uuid;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if coalesce(v_role,'') not in ('super_admin','operator') then raise exception 'No autorizado para ajustar billeteras'; end if;
  if v_role='operator' then perform public.admin_operator_assert_module('payments'); end if;
  v_channel:=public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  if p_idempotency_key is null then raise exception 'Falta la clave de operación'; end if;
  if p_direction not in ('credit','debit') then raise exception 'Tipo de ajuste inválido'; end if;
  if p_amount is null or p_amount<=0 or p_amount>10000000 then raise exception 'Importe inválido'; end if;
  if length(trim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'Indica un motivo de 3 a 500 caracteres'; end if;

  select * into v_operation from public.admin_financial_operations o
    where o.actor_id=auth.uid() and o.channel=v_channel and o.idempotency_key=p_idempotency_key;
  if found then
    if v_operation.operation_type<>'wallet_adjustment'
       or v_operation.target_user_id is distinct from p_user_id
       or v_operation.zone_id is distinct from v_zone
       or v_operation.amount is distinct from p_amount
       or v_operation.reason is distinct from trim(p_reason)
       or (v_operation.balance_after-v_operation.balance_before) is distinct from
         (case when p_direction='credit' then p_amount else -p_amount end) then
      raise exception 'La clave de operación ya se usó con otros datos';
    end if;
    return jsonb_build_object('ok',true,'already_processed',true,
      'operation_id',v_operation.id,'balance_after',v_operation.balance_after,
      'debt_amount',coalesce((select d.amount from public.admin_wallet_adjustment_debts d
        where d.operation_id=v_operation.id),0));
  end if;

  select z.country_code,upper(z.currency_code) into v_country,v_currency
    from public.service_zones z where z.id=v_zone;
  if v_country is null then raise exception 'Zona no encontrada'; end if;
  select u.last_zone_id,case when d.id is null then 'passenger' else 'driver' end
    into v_target_zone,v_target_role from public.users u
    left join public.driver_profiles d on d.id=u.id
    where u.id=p_user_id and u.account_status='active';
  if not found then raise exception 'Usuario no encontrado o inactivo'; end if;
  if v_target_role='driver' then
    select d.zone_id into v_target_zone from public.driver_profiles d where d.id=p_user_id;
  end if;
  if v_target_zone is distinct from v_zone then raise exception 'El usuario no pertenece a la zona seleccionada'; end if;
  if (v_channel='preview' and not public.is_active_audit_user(p_user_id))
     or (v_channel='production' and public.is_active_audit_user(p_user_id)) then
    raise exception 'La cuenta pertenece a otro entorno';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'admin-wallet-adjustment:'||p_user_id::text||':'||v_country||':'||v_channel,0));
  select * into v_account from public.wallet_country_accounts w
    where w.user_id=p_user_id and w.country_code=v_country and w.channel=v_channel for update;
  if found then
    if upper(v_account.currency)<>v_currency then raise exception 'La moneda de la billetera no coincide con la zona'; end if;
    v_before:=v_account.balance;
  end if;
  v_delta:=case when p_direction='credit' then p_amount else -p_amount end;
  v_after:=v_before+v_delta;
  if v_currency='CLP' and p_amount<>trunc(p_amount) then raise exception 'Los importes CLP deben ser enteros'; end if;
  if v_currency<>'CLP' and p_amount<>round(p_amount,2) then raise exception 'La moneda admite hasta dos decimales'; end if;
  if v_channel='production' then
    select * into v_legacy from public.wallet_accounts w where w.user_id=p_user_id for update;
    if found then
      if upper(v_legacy.currency)<>v_currency and coalesce(v_legacy.balance,0)<>0 then
        raise exception 'La billetera histórica tiene otra moneda; requiere revisión central';
      end if;
    elsif v_before<>0 then
      insert into public.wallet_accounts(user_id,balance,currency,updated_at)
      values(p_user_id,v_before,v_currency,now());
    end if;
  end if;
  insert into public.wallet_transactions(user_id,amount,type,status,reference,country_code,channel)
    values(p_user_id,v_delta,'adjustment','completed',
      'Ajuste administrativo: '||trim(p_reason),v_country,v_channel)
    returning id into v_tx;
  if v_channel='production' then perform public.mirror_legacy_wallet_delta(p_user_id,v_currency,v_delta); end if;
  insert into public.admin_financial_operations(
    operation_type,actor_id,target_user_id,target_role,zone_id,channel,
    country_code,currency_code,amount,balance_before,balance_after,
    wallet_transaction_id,reason,idempotency_key
  ) values ('wallet_adjustment',auth.uid(),p_user_id,v_target_role,v_zone,v_channel,
    v_country,v_currency,p_amount,v_before,v_after,v_tx,trim(p_reason),p_idempotency_key)
    returning * into v_operation;

  if p_direction='debit' then
    v_debt_amount:=greatest(0,-v_after)-greatest(0,-v_before);
    if v_debt_amount>0 then
      insert into public.admin_wallet_adjustment_debts(
        operation_id,user_id,role,zone_id,channel,country_code,currency_code,
        amount,remaining_amount,reason
      ) values(v_operation.id,p_user_id,v_target_role,v_zone,v_channel,v_country,
        v_currency,v_debt_amount,v_debt_amount,trim(p_reason))
      returning id into v_debt_id;
    end if;
  else
    perform public.apply_admin_adjustment_debt_credit(p_user_id,v_country,v_channel,p_amount);
  end if;
  return jsonb_build_object('ok',true,'already_processed',false,
    'operation_id',v_operation.id,'wallet_transaction_id',v_tx,
    'balance_before',v_before,'balance_after',v_after,
    'currency_code',v_currency,'debt_id',v_debt_id,'debt_amount',v_debt_amount);
end;
$fn$;
revoke all on function public.admin_finance_adjust_wallet_v1(uuid,uuid,text,numeric,text,uuid)
  from public,anon;
grant execute on function public.admin_finance_adjust_wallet_v1(uuid,uuid,text,numeric,text,uuid)
  to authenticated;
