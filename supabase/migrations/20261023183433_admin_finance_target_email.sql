-- Incluye el correo de la cuenta en las vistas administrativas de deudas y ajustes.
-- La RPC sigue restringida por rol, módulo, zona y entorno autenticados.

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
          u.full_name,u.phone,au.email,
          coalesce(op.reason,'') as resolution_reason,
          op.created_at as resolved_at,
          actor.full_name as resolved_by_name
        from public.cancellation_fee_debts d
        join public.users u on u.id=d.user_id
        left join auth.users au on au.id=u.id
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
            or coalesce(au.email,'') ilike '%'||v_search||'%'
            or d.trip_id::text ilike '%'||v_search||'%')
        order by d.created_at desc limit greatest(1,least(coalesce(p_limit,200),500))
      ) drow
    ),'[]'::jsonb),
    'adjustments',coalesce((
      select jsonb_agg(to_jsonb(arow) order by arow.created_at desc)
      from (
        select o.id,o.operation_type,o.target_user_id,o.target_role,o.zone_id,
          o.currency_code,o.amount,o.balance_before,o.balance_after,o.reason,o.created_at,
          u.full_name,u.phone,au.email
        from public.admin_financial_operations o
        join public.users u on u.id=o.target_user_id
        left join auth.users au on au.id=u.id
        where o.zone_id=v_zone and o.channel=v_channel
          and o.operation_type='wallet_adjustment'
          and (v_role_filter='all' or o.target_role=v_role_filter)
          and (v_search is null or u.full_name ilike '%'||v_search||'%'
            or coalesce(u.phone,'') ilike '%'||v_search||'%'
            or coalesce(au.email,'') ilike '%'||v_search||'%')
        order by o.created_at desc limit greatest(1,least(coalesce(p_limit,200),500))
      ) arow
    ),'[]'::jsonb),
    'targets',coalesce((
      select jsonb_agg(to_jsonb(trow) order by trow.full_name)
      from (
        select u.id as user_id,u.full_name,u.phone,au.email,
          case when dp.id is null then 'passenger' else 'driver' end as role,
          coalesce(w.balance,0) as balance,
          coalesce(w.currency,v_currency) as currency_code,
          v_zone as zone_id
        from public.users u
        left join auth.users au on au.id=u.id
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
            or coalesce(au.email,'') ilike '%'||v_search||'%'
            or u.id::text ilike '%'||v_search||'%')
        order by u.full_name limit 100
      ) trow
    ),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$fn$;

revoke all on function public.admin_finance_debts_v1(uuid,text,text,text,integer) from public,anon;
grant execute on function public.admin_finance_debts_v1(uuid,text,text,text,integer) to authenticated;
