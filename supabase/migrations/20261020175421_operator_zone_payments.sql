-- Pagos de zona: se atribuyen solo por viaje o pedido con zona inmutable.
-- Movimientos globales o sin zona comprobable NO se exponen al operador.
create or replace function public.admin_operator_payment_overview(
 p_zone_id uuid,p_from timestamptz default null,p_to timestamptz default null,
 p_limit integer default 100
) returns jsonb language plpgsql stable security definer set search_path='public'
as $pay$
declare v_zone uuid;v_output jsonb;
begin
 perform public.admin_operator_assert_module('payments');
 v_zone:=public.admin_effective_zone_id(p_zone_id);
 with eligible as (
  select p.id,p.amount,p.currency,p.status,p.method,p.created_at,p.paid_at,
         p.trip_id,p.delivery_id,
         case
          when p.trip_id is not null then rr.zone_id
          when p.delivery_id is not null then mo.zone_id
          else null end as authoritative_zone
  from public.payment_transactions p
  left join public.trips t on t.id=p.trip_id
  left join public.ride_requests rr on rr.id=t.ride_request_id
  left join public.delivery_requests dr on dr.id=p.delivery_id
  left join public.marketplace_orders mo on mo.id=dr.marketplace_order_id
  where p.channel='production'
   and (p_from is null or p.created_at>=p_from)
   and (p_to is null or p.created_at<p_to)
 ), zonal as (select * from eligible where authoritative_zone=v_zone)
 select jsonb_build_object(
  'zone_id',v_zone,
  'paid_count',(select count(*) from zonal where status='paid'),
  'pending_count',(select count(*) from zonal where status='pending'),
  'paid_by_currency',coalesce((
    select jsonb_object_agg(currency,total) from
      (select currency,sum(amount) total from zonal
       where status='paid' group by currency) q
  ),'{}'::jsonb),
  'recent',coalesce((
    select jsonb_agg(to_jsonb(r) order by r.created_at desc)
    from (select id,amount,currency,status,method,created_at,paid_at,trip_id,delivery_id
      from zonal order by created_at desc
      limit greatest(1,least(coalesce(p_limit,100),200))) r
  ),'[]'::jsonb)
 ) into v_output;
 return v_output;
end
$pay$;

revoke all on function public.admin_operator_payment_overview(uuid,timestamptz,timestamptz,integer) from public,anon;
grant execute on function public.admin_operator_payment_overview(uuid,timestamptz,timestamptz,integer) to authenticated,service_role;
