-- Gestión de deuda por cancelación y ajustes manuales de billetera desde Adminexpress.
-- Las operaciones pasan por RPC: el cliente no modifica deuda ni libros de saldo.

create table if not exists public.admin_financial_operations (
  id uuid primary key default gen_random_uuid(),
  operation_type text not null check (operation_type in ('debt_settlement','wallet_adjustment')),
  actor_id uuid not null references public.users(id),
  target_user_id uuid not null references public.users(id),
  target_role text not null check (target_role in ('passenger','driver')),
  zone_id uuid not null references public.service_zones(id),
  channel text not null check (channel in ('preview','production')),
  country_code text not null,
  currency_code text not null,
  amount numeric not null check (amount > 0),
  balance_before numeric,
  balance_after numeric,
  debt_id uuid references public.cancellation_fee_debts(id),
  wallet_transaction_id uuid references public.wallet_transactions(id),
  reason text not null check (length(trim(reason)) between 3 and 500),
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  constraint admin_financial_operations_idempotency_key unique(actor_id,channel,idempotency_key),
  constraint admin_financial_operations_debt_id_unique unique(debt_id),
  constraint admin_financial_operations_wallet_tx_unique unique(wallet_transaction_id)
);

create index if not exists admin_financial_operations_zone_created_idx
  on public.admin_financial_operations(zone_id,channel,created_at desc);
create index if not exists admin_financial_operations_target_created_idx
  on public.admin_financial_operations(target_user_id,channel,created_at desc);

alter table public.admin_financial_operations enable row level security;
revoke all on public.admin_financial_operations from public, anon, authenticated;

create or replace function public.admin_finance_debts_v1(
  p_zone_id uuid,
  p_status text default 'pending',
  p_role text default 'all',
  p_search text default null,
  p_limit integer default 200
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
declare
  v_channel text;
  v_zone uuid;
  v_admin_role text;
  v_country text;
  v_currency text;
  v_status text := lower(trim(coalesce(p_status,'pending')));
  v_role_filter text := lower(trim(coalesce(p_role,'all')));
  v_search text := nullif(trim(coalesce(p_search,'')),'');
  v_result jsonb;
begin
  select a.access_role into v_admin_role
  from public.admin_users a
  join public.users u on u.id=a.user_id
  where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if v_admin_role not in ('super_admin','operator') then
    raise exception 'No autorizado para consultar finanzas';
  end if;
  if v_admin_role='operator' then
    perform public.admin_operator_assert_module('payments');
  end if;
  v_channel := public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone := public.admin_effective_zone_id(p_zone_id);
  if v_status not in ('pending','settled','all') then raise exception 'Filtro de deuda inválido'; end if;
  if v_role_filter not in ('all','passenger','driver') then raise exception 'Filtro de usuario inválido'; end if;

  select z.country_code, upper(z.currency_code) into v_country,v_currency
  from public.service_zones z where z.id=v_zone;
  if v_country is null then raise exception 'Zona no encontrada'; end if;

  select jsonb_build_object(
    'channel',v_channel,
    'zone_id',v_zone,
    'country_code',v_country,
    'currency_code',v_currency,
    'debts',coalesce((
      select jsonb_agg(to_jsonb(drow) order by drow.created_at desc)
      from (
        select d.id as debt_id,d.user_id,d.trip_id,d.zone_id,d.role,
          d.amount,d.currency_code,d.country_code,d.reason,d.created_at,d.paid_at,
          case when d.paid_at is null then 'pending' else 'settled' end as status,
          u.full_name,u.phone,
          coalesce(op.reason,'') as resolution_reason,
          op.created_at as resolved_at,
          actor.full_name as resolved_by_name
        from public.cancellation_fee_debts d
        join public.users u on u.id=d.user_id
        left join public.admin_financial_operations op
          on op.debt_id=d.id and op.operation_type='debt_settlement'
        left join public.users actor on actor.id=op.actor_id
        where d.zone_id=v_zone and d.channel=v_channel and d.country_code=v_country
          and (v_status='all' or (v_status='pending' and d.paid_at is null)
            or (v_status='settled' and d.paid_at is not null))
          and (v_role_filter='all' or d.role=v_role_filter)
          and (v_channel<>'preview' or public.is_active_audit_user(d.user_id))
          and (v_channel<>'production' or not public.is_active_audit_user(d.user_id))
          and (v_search is null or u.full_name ilike '%'||v_search||'%'
            or coalesce(u.phone,'') ilike '%'||v_search||'%'
            or d.trip_id::text ilike '%'||v_search||'%')
        order by d.created_at desc limit greatest(1,least(coalesce(p_limit,200),500))
      ) drow
    ),'[]'::jsonb),
    'adjustments',coalesce((
      select jsonb_agg(to_jsonb(arow) order by arow.created_at desc)
      from (
        select o.id,o.operation_type,o.target_user_id,o.target_role,o.zone_id,
          o.currency_code,o.amount,o.balance_before,o.balance_after,o.reason,o.created_at,
          u.full_name,u.phone
        from public.admin_financial_operations o
        join public.users u on u.id=o.target_user_id
        where o.zone_id=v_zone and o.channel=v_channel
          and o.operation_type='wallet_adjustment'
          and (v_role_filter='all' or o.target_role=v_role_filter)
          and (v_search is null or u.full_name ilike '%'||v_search||'%'
            or coalesce(u.phone,'') ilike '%'||v_search||'%')
        order by o.created_at desc limit greatest(1,least(coalesce(p_limit,200),500))
      ) arow
    ),'[]'::jsonb),
    'targets',coalesce((
      select jsonb_agg(to_jsonb(trow) order by trow.full_name)
      from (
        select u.id as user_id,u.full_name,u.phone,
          case when dp.id is null then 'passenger' else 'driver' end as role,
          coalesce(w.balance,0) as balance,
          coalesce(w.currency,v_currency) as currency_code,
          v_zone as zone_id
        from public.users u
        left join public.driver_profiles dp on dp.id=u.id and dp.zone_id=v_zone
        left join public.wallet_country_accounts w
          on w.user_id=u.id and w.country_code=v_country and w.channel=v_channel
        where u.account_status='active'
          and (dp.id is not null or u.last_zone_id=v_zone)
          and (v_channel<>'preview' or public.is_active_audit_user(u.id))
          and (v_channel<>'production' or not public.is_active_audit_user(u.id))
          and (v_role_filter='all' or (v_role_filter='driver' and dp.id is not null)
            or (v_role_filter='passenger' and dp.id is null))
          and (v_search is null or u.full_name ilike '%'||v_search||'%'
            or coalesce(u.phone,'') ilike '%'||v_search||'%'
            or u.id::text ilike '%'||v_search||'%')
        order by u.full_name limit 100
      ) trow
    ),'[]'::jsonb)
  ) into v_result;
  return v_result;
end
$fn$;

create or replace function public.admin_finance_settle_debt_v1(
  p_zone_id uuid,p_debt_id uuid,p_reason text,p_idempotency_key uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $fn$
declare
  v_channel text;
  v_zone uuid;
  v_role text;
  v_debt public.cancellation_fee_debts%rowtype;
  v_operation public.admin_financial_operations%rowtype;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if v_role not in ('super_admin','operator') then
    raise exception 'No autorizado para liquidar deudas';
  end if;
  if v_role='operator' then
    perform public.admin_operator_assert_module('payments');
  end if;
  v_channel:=public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  if p_idempotency_key is null then raise exception 'Falta la clave de operación'; end if;
  if length(trim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'Indica un motivo de 3 a 500 caracteres'; end if;

  select * into v_operation from public.admin_financial_operations o
    where o.actor_id=auth.uid() and o.channel=v_channel and o.idempotency_key=p_idempotency_key;
  if found then
    if v_operation.operation_type<>'debt_settlement' or v_operation.debt_id is distinct from p_debt_id
       or v_operation.zone_id is distinct from v_zone or v_operation.reason is distinct from trim(p_reason) then
      raise exception 'La clave de operación ya se usó con otros datos';
    end if;
    return jsonb_build_object('ok',true,'already_processed',true,'operation_id',v_operation.id);
  end if;

  select * into v_debt from public.cancellation_fee_debts d
    where d.id=p_debt_id and d.zone_id=v_zone and d.channel=v_channel
    for update;
  if not found then raise exception 'Deuda no encontrada en tu zona y entorno'; end if;
  if v_debt.paid_at is not null then raise exception 'La deuda ya está liquidada'; end if;
  if (v_channel='preview' and not public.is_active_audit_user(v_debt.user_id))
     or (v_channel='production' and public.is_active_audit_user(v_debt.user_id)) then
    raise exception 'La deuda pertenece a otro entorno';
  end if;

  insert into public.admin_financial_operations(
    operation_type,actor_id,target_user_id,target_role,zone_id,channel,
    country_code,currency_code,amount,debt_id,reason,idempotency_key
  ) values (
    'debt_settlement',auth.uid(),v_debt.user_id,v_debt.role,v_zone,v_channel,
    v_debt.country_code,v_debt.currency_code,v_debt.amount,v_debt.id,
    trim(p_reason),p_idempotency_key
  ) returning * into v_operation;
  update public.cancellation_fee_debts set paid_at=now()
    where id=v_debt.id and paid_at is null;
  if not found then raise exception 'La deuda cambió durante la operación'; end if;
  return jsonb_build_object('ok',true,'already_processed',false,'operation_id',v_operation.id,'amount',v_debt.amount,'currency_code',v_debt.currency_code);
end
$fn$;

create or replace function public.admin_finance_adjust_wallet_v1(
  p_zone_id uuid,p_user_id uuid,p_direction text,p_amount numeric,
  p_reason text,p_idempotency_key uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $fn$
declare
  v_channel text;
  v_zone uuid;
  v_role text;
  v_target_role text;
  v_target_zone uuid;
  v_country text;
  v_currency text;
  v_delta numeric;
  v_before numeric:=0;
  v_after numeric;
  v_account public.wallet_country_accounts%rowtype;
  v_legacy public.wallet_accounts%rowtype;
  v_tx uuid;
  v_operation public.admin_financial_operations%rowtype;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if v_role not in ('super_admin','operator') then
    raise exception 'No autorizado para ajustar billeteras';
  end if;
  if v_role='operator' then
    perform public.admin_operator_assert_module('payments');
  end if;
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
       or v_operation.balance_after-v_operation.balance_before is distinct from
         case when p_direction='credit' then p_amount else -p_amount end then
      raise exception 'La clave de operación ya se usó con otros datos';
    end if;
    return jsonb_build_object('ok',true,'already_processed',true,'operation_id',v_operation.id,'balance_after',v_operation.balance_after);
  end if;

  select z.country_code,upper(z.currency_code) into v_country,v_currency
    from public.service_zones z where z.id=v_zone;
  if v_country is null then raise exception 'Zona no encontrada'; end if;
  select u.last_zone_id,case when d.id is null then 'passenger' else 'driver' end
    into v_target_zone,v_target_role
    from public.users u left join public.driver_profiles d on d.id=u.id
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

  perform pg_advisory_xact_lock(hashtextextended('admin-wallet-adjustment:'||p_user_id::text||':'||v_country||':'||v_channel,0));
  select * into v_account from public.wallet_country_accounts w
    where w.user_id=p_user_id and w.country_code=v_country and w.channel=v_channel
    for update;
  if found then
    if upper(v_account.currency)<>v_currency then raise exception 'La moneda de la billetera no coincide con la zona'; end if;
    v_before:=v_account.balance;
  end if;
  v_delta:=case when p_direction='credit' then p_amount else -p_amount end;
  v_after:=v_before+v_delta;
  if v_after<0 then raise exception 'El ajuste no puede dejar saldo negativo'; end if;
  if v_currency='CLP' and p_amount<>trunc(p_amount) then raise exception 'Los importes CLP deben ser enteros'; end if;
  if v_currency<>'CLP' and p_amount<>round(p_amount,2) then raise exception 'La moneda admite hasta dos decimales'; end if;

  if v_channel='production' then
    select * into v_legacy from public.wallet_accounts w where w.user_id=p_user_id for update;
    if found then
      if upper(v_legacy.currency)<>v_currency and coalesce(v_legacy.balance,0)<>0 then
        raise exception 'La billetera histórica tiene otra moneda; requiere revisión central';
      end if;
      if upper(v_legacy.currency)=v_currency and v_legacy.balance+v_delta<0 then
        raise exception 'El ajuste dejaría negativa la billetera histórica';
      end if;
    elsif v_before>0 then
      -- Reconstituye el espejo legacy a partir del saldo regional actual antes
      -- de aplicar el delta, sin permitir crear una cuenta legacy negativa.
      insert into public.wallet_accounts(user_id,balance,currency,updated_at)
      values(p_user_id,v_before,v_currency,now());
    elsif p_direction='debit' then
      raise exception 'No se puede debitar: la billetera no tiene saldo';
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
  ) values (
    'wallet_adjustment',auth.uid(),p_user_id,v_target_role,v_zone,v_channel,
    v_country,v_currency,p_amount,v_before,v_after,v_tx,trim(p_reason),p_idempotency_key
  ) returning * into v_operation;
  return jsonb_build_object('ok',true,'already_processed',false,'operation_id',v_operation.id,'wallet_transaction_id',v_tx,'balance_before',v_before,'balance_after',v_after,'currency_code',v_currency);
end
$fn$;

revoke all on function public.admin_finance_debts_v1(uuid,text,text,text,integer) from public,anon;
revoke all on function public.admin_finance_settle_debt_v1(uuid,uuid,text,uuid) from public,anon;
revoke all on function public.admin_finance_adjust_wallet_v1(uuid,uuid,text,numeric,text,uuid) from public,anon;
grant execute on function public.admin_finance_debts_v1(uuid,text,text,text,integer) to authenticated;
grant execute on function public.admin_finance_settle_debt_v1(uuid,uuid,text,uuid) to authenticated;
grant execute on function public.admin_finance_adjust_wallet_v1(uuid,uuid,text,numeric,text,uuid) to authenticated;
