-- Backfill only historical administrative overdrafts whose remaining negative
-- wallet balance is fully explained by completed admin adjustment entries.
-- This deliberately excludes mixed balances that may include commissions or
-- other financial activity; those require an operator review.
with adjustment_debits as (
  select o.id as operation_id,o.target_user_id as user_id,o.target_role as role,
    o.zone_id,o.channel,o.country_code,o.currency_code,o.reason,o.created_at,
    greatest(0,-coalesce(o.balance_after,0))
      - greatest(0,-coalesce(o.balance_before,0)) as debt_amount
  from public.admin_financial_operations o
  join public.wallet_country_accounts w
    on w.user_id=o.target_user_id and w.country_code=o.country_code
      and w.channel=o.channel
  where o.operation_type='wallet_adjustment'
    and o.channel='production'
    and o.balance_after<0
    and greatest(0,-coalesce(o.balance_after,0))
      > greatest(0,-coalesce(o.balance_before,0))
    and o.admin_adjustment_debt_id is null
    and w.balance<0
    and not public.is_active_audit_user(o.target_user_id)
    and not exists (
      select 1 from public.admin_wallet_adjustment_debts d
      where d.operation_id=o.id
    )
), safe_accounts as (
  select d.user_id,d.country_code,d.channel,-w.balance as outstanding
  from adjustment_debits d
  join public.wallet_country_accounts w on w.user_id=d.user_id
    and w.country_code=d.country_code and w.channel=d.channel
  group by d.user_id,d.country_code,d.channel,w.balance
  having sum(d.debt_amount)=-w.balance
    and not exists (
      select 1 from public.wallet_transactions t
      where t.user_id=d.user_id and t.country_code=d.country_code
        and t.channel=d.channel
        and (t.type<>'adjustment'
          or t.reference not like 'Ajuste administrativo:%')
    )
), inserted as (
  insert into public.admin_wallet_adjustment_debts(
    operation_id,user_id,role,zone_id,channel,country_code,currency_code,
    amount,remaining_amount,reason,created_at
  )
  select d.operation_id,d.user_id,d.role,d.zone_id,d.channel,d.country_code,
    d.currency_code,d.debt_amount,d.debt_amount,d.reason,d.created_at
  from adjustment_debits d
  join safe_accounts a on a.user_id=d.user_id
    and a.country_code=d.country_code and a.channel=d.channel
  where d.debt_amount>0
  on conflict(operation_id) do nothing
  returning id,operation_id
)
update public.admin_financial_operations o
set admin_adjustment_debt_id=i.id
from inserted i
where o.id=i.operation_id;
