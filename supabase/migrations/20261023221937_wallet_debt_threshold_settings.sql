-- Configurable wallet debt tolerance, scoped to the authenticated runtime and
-- operating zone. A missing row defaults to zero tolerance, preserving the
-- existing behavior (any positive debt blocks work).
create table if not exists public.zone_wallet_debt_limits (
  channel text not null check (channel in ('preview','production')),
  zone_id uuid not null references public.service_zones(id) on delete cascade,
  passenger_limit numeric(14,2) not null default 0
    check (passenger_limit >= 0 and passenger_limit <= 10000000),
  driver_limit numeric(14,2) not null default 0
    check (driver_limit >= 0 and driver_limit <= 10000000),
  currency_code text not null,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  primary key (channel, zone_id)
);
alter table public.zone_wallet_debt_limits enable row level security;
revoke all on public.zone_wallet_debt_limits from public,anon,authenticated;

create table if not exists public.zone_wallet_debt_limit_audit (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('preview','production')),
  zone_id uuid not null references public.service_zones(id) on delete cascade,
  actor_id uuid not null references auth.users(id),
  currency_code text not null,
  passenger_limit_before numeric(14,2) not null,
  passenger_limit_after numeric(14,2) not null,
  driver_limit_before numeric(14,2) not null,
  driver_limit_after numeric(14,2) not null,
  created_at timestamptz not null default now()
);
create index if not exists zone_wallet_debt_limit_audit_zone_idx
  on public.zone_wallet_debt_limit_audit(zone_id,channel,created_at desc);
alter table public.zone_wallet_debt_limit_audit enable row level security;
revoke all on public.zone_wallet_debt_limit_audit from public,anon,authenticated;

create or replace function public.admin_wallet_debt_limits_get_v1(
  p_zone_id uuid
) returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_role text;
  v_channel text;
  v_zone uuid;
  v_currency text;
  v_rule public.zone_wallet_debt_limits%rowtype;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if coalesce(v_role,'') not in ('super_admin','operator') then
    raise exception 'No autorizado para consultar los topes de deuda';
  end if;
  if v_role='operator' then perform public.admin_operator_assert_module('payments'); end if;
  v_channel:=public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  select upper(z.currency_code) into v_currency
    from public.service_zones z where z.id=v_zone;
  if v_currency is null then raise exception 'Zona no encontrada'; end if;
  select * into v_rule from public.zone_wallet_debt_limits r
    where r.zone_id=v_zone and r.channel=v_channel;
  return jsonb_build_object(
    'zone_id',v_zone,'channel',v_channel,'currency_code',v_currency,
    'passenger_limit',coalesce(v_rule.passenger_limit,0),
    'driver_limit',coalesce(v_rule.driver_limit,0),
    'configured',found
  );
end;
$fn$;
revoke all on function public.admin_wallet_debt_limits_get_v1(uuid)
  from public,anon;
grant execute on function public.admin_wallet_debt_limits_get_v1(uuid)
  to authenticated;

create or replace function public.admin_wallet_debt_limits_set_v1(
  p_zone_id uuid,p_passenger_limit numeric,p_driver_limit numeric
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare
  v_role text;
  v_channel text;
  v_zone uuid;
  v_country text;
  v_currency text;
  v_old_passenger numeric:=0;
  v_old_driver numeric:=0;
begin
  select a.access_role into v_role from public.admin_users a
    join public.users u on u.id=a.user_id
    where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if coalesce(v_role,'') not in ('super_admin','operator') then
    raise exception 'No autorizado para cambiar los topes de deuda';
  end if;
  if v_role='operator' then perform public.admin_operator_assert_module('payments'); end if;
  v_channel:=public.admin_current_runtime_environment();
  perform public.admin_assert_environment(v_channel);
  v_zone:=public.admin_effective_zone_id(p_zone_id);
  select z.country_code,upper(z.currency_code) into v_country,v_currency
    from public.service_zones z where z.id=v_zone;
  if v_country is null then raise exception 'Zona no encontrada'; end if;
  if p_passenger_limit is null or p_driver_limit is null
     or p_passenger_limit<0 or p_driver_limit<0
     or p_passenger_limit>10000000 or p_driver_limit>10000000 then
    raise exception 'El tope debe estar entre 0 y 10.000.000';
  end if;
  if v_currency='CLP' and
     (p_passenger_limit<>trunc(p_passenger_limit)
       or p_driver_limit<>trunc(p_driver_limit)) then
    raise exception 'Los topes CLP deben ser números enteros';
  end if;
  if v_currency<>'CLP' and
     (p_passenger_limit<>round(p_passenger_limit,2)
       or p_driver_limit<>round(p_driver_limit,2)) then
    raise exception 'Los topes admiten hasta dos decimales';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'zone-wallet-debt-limit:'||v_channel||':'||v_zone::text,0));
  select r.passenger_limit,r.driver_limit
    into v_old_passenger,v_old_driver
    from public.zone_wallet_debt_limits r
    where r.channel=v_channel and r.zone_id=v_zone
    for update;
  v_old_passenger:=coalesce(v_old_passenger,0);
  v_old_driver:=coalesce(v_old_driver,0);

  insert into public.zone_wallet_debt_limits(
    channel,zone_id,passenger_limit,driver_limit,currency_code,updated_by,updated_at
  ) values (
    v_channel,v_zone,p_passenger_limit,p_driver_limit,v_currency,auth.uid(),now()
  ) on conflict(channel,zone_id) do update set
    passenger_limit=excluded.passenger_limit,
    driver_limit=excluded.driver_limit,
    currency_code=excluded.currency_code,
    updated_by=excluded.updated_by,
    updated_at=now();

  insert into public.zone_wallet_debt_limit_audit(
    channel,zone_id,actor_id,currency_code,
    passenger_limit_before,passenger_limit_after,
    driver_limit_before,driver_limit_after
  ) values (
    v_channel,v_zone,auth.uid(),v_currency,
    v_old_passenger,p_passenger_limit,v_old_driver,p_driver_limit
  );

  -- Apply a lowered driver threshold immediately to idle drivers. Active rides
  -- and deliveries can finish, but server-side claim guards stop new work.
  update public.driver_profiles dp set online_status='offline',updated_at=now()
  where dp.zone_id=v_zone and dp.online_status='online'
    and not exists(select 1 from public.trips t where t.driver_id=dp.id
      and t.status not in ('completed','cancelled'))
    and not exists(select 1 from public.delivery_requests d where d.courier_id=dp.id
      and d.status not in ('delivered','cancelled'))
    and (
      coalesce((select sum(d.remaining_amount)
        from public.admin_wallet_adjustment_debts d
        where d.user_id=dp.id and d.role='driver' and d.zone_id=v_zone
          and d.channel=v_channel and d.remaining_amount>0),0)
      + coalesce((select sum(d.amount)
        from public.cancellation_fee_debts d
        where d.user_id=dp.id and d.role='driver' and d.zone_id=v_zone
          and d.channel=v_channel and d.paid_at is null),0)
    )>p_driver_limit;

  return public.admin_wallet_debt_limits_get_v1(v_zone);
end;
$fn$;
revoke all on function public.admin_wallet_debt_limits_set_v1(uuid,numeric,numeric)
  from public,anon;
grant execute on function public.admin_wallet_debt_limits_set_v1(uuid,numeric,numeric)
  to authenticated;
