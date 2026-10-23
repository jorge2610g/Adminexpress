-- Permite que ajustes administrativos de débito creen un saldo deudor auditable.
-- El saldo regional y el espejo histórico reciben el mismo delta en una transacción.

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
       or (v_operation.balance_after-v_operation.balance_before) is distinct from
         (case when p_direction='credit' then p_amount else -p_amount end) then
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
  if v_currency='CLP' and p_amount<>trunc(p_amount) then raise exception 'Los importes CLP deben ser enteros'; end if;
  if v_currency<>'CLP' and p_amount<>round(p_amount,2) then raise exception 'La moneda admite hasta dos decimales'; end if;

  if v_channel='production' then
    select * into v_legacy from public.wallet_accounts w where w.user_id=p_user_id for update;
    if found then
      if upper(v_legacy.currency)<>v_currency and coalesce(v_legacy.balance,0)<>0 then
        raise exception 'La billetera histórica tiene otra moneda; requiere revisión central';
      end if;
    elsif v_before<>0 then
      -- Reconstruye el espejo histórico desde el saldo zonal actual; un débito
      -- posterior puede dejar ambos libros en negativo como deuda administrativa.
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
  ) values (
    'wallet_adjustment',auth.uid(),p_user_id,v_target_role,v_zone,v_channel,
    v_country,v_currency,p_amount,v_before,v_after,v_tx,trim(p_reason),p_idempotency_key
  ) returning * into v_operation;
  return jsonb_build_object('ok',true,'already_processed',false,'operation_id',v_operation.id,'wallet_transaction_id',v_tx,'balance_before',v_before,'balance_after',v_after,'currency_code',v_currency);
end;
$fn$;

revoke all on function public.admin_finance_adjust_wallet_v1(uuid,uuid,text,numeric,text,uuid) from public,anon;
grant execute on function public.admin_finance_adjust_wallet_v1(uuid,uuid,text,numeric,text,uuid) to authenticated;
