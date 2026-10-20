-- Backup de definiciones previas a fase 2. Restaurar SOLO si se necesita revertir.
-- No borra datos de operadores, zonas ni usuarios.
begin;

-- admin_dashboard_state_v2
CREATE OR REPLACE FUNCTION public.admin_dashboard_state_v2(p_channel text DEFAULT 'production'::text, p_zone_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
  v_now timestamptz:=now();
  v_today timestamptz:=date_trunc('day',now());
  v_drivers jsonb;
  v_trips jsonb;
  v_deliveries jsonb;
  v_emergencies jsonb;
  v_activity jsonb;
  v_metrics jsonb;
begin
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  select coalesce(jsonb_agg(x order by x->>'name'),'[]'::jsonb)
    into v_drivers
  from jsonb_array_elements(
    public.admin_driver_list_v3(v_channel,v_zone)
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',t.id,'channel',t.channel,'zone_id',rr.zone_id,
        'zone_key',z.zone_key,'zone_name',z.name,
        'country',z.country,'country_code',z.country_code,
        'status',t.status,'final_fare',t.final_fare,
        'payment_status',t.payment_status,'created_at',t.created_at,
        'passenger_id',t.passenger_id,'driver_id',t.driver_id,
        'passenger_name',pu.full_name,'driver_name',du.full_name,
        'pickup_address',rr.pickup_address,
        'pickup_latitude',rr.pickup_latitude,
        'pickup_longitude',rr.pickup_longitude,
        'destination_address',rr.destination_address,
        'destination_latitude',rr.destination_latitude,
        'destination_longitude',rr.destination_longitude,
        'category',rr.category
      )
      order by t.created_at desc
    ),
    '[]'::jsonb
  )
  into v_trips
  from public.trips t
  join public.ride_requests rr on rr.id=t.ride_request_id
  left join public.service_zones z on z.id=rr.zone_id
  left join public.users pu on pu.id=t.passenger_id
  left join public.users du on du.id=t.driver_id
  where t.channel=v_channel
    and rr.channel=v_channel
    and rr.zone_id=v_zone
    and t.status not in ('completed','cancelled');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',d.id,'channel',d.channel,'zone_id',z.id,
        'zone_key',z.zone_key,'zone_name',z.name,
        'country',z.country,'country_code',z.country_code,
        'status',d.status,'proposed_fare',d.proposed_fare,
        'payment_method',d.payment_method,'created_at',d.created_at,
        'customer_id',d.customer_id,'courier_id',d.courier_id,
        'customer_name',cu.full_name,'courier_name',du.full_name,
        'pickup_address',d.pickup_address,
        'pickup_latitude',d.pickup_latitude,
        'pickup_longitude',d.pickup_longitude,
        'dropoff_address',d.dropoff_address,
        'dropoff_latitude',d.dropoff_latitude,
        'dropoff_longitude',d.dropoff_longitude,
        'package_type',d.package_type
      )
      order by d.created_at desc
    ),
    '[]'::jsonb
  )
  into v_deliveries
  from public.delivery_requests d
  left join public.users cu on cu.id=d.customer_id
  left join public.users du on du.id=d.courier_id
  left join lateral (
    select public.service_zone_id_for_point(
      d.pickup_latitude::numeric,
      d.pickup_longitude::numeric
    ) as zone_id
  ) dz on true
  left join public.service_zones z on z.id=dz.zone_id
  where d.channel=v_channel
    and z.id=v_zone
    and d.status not in ('delivered','cancelled');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',e.id,'channel',coalesce(et.channel,ed.channel,v_channel),
        'zone_id',ez.id,'zone_key',ez.zone_key,'zone_name',ez.name,
        'country',ez.country,'country_code',ez.country_code,
        'user_id',e.user_id,'user_name',u.full_name,
        'trip_id',e.trip_id,'delivery_id',e.delivery_id,
        'latitude',e.latitude,'longitude',e.longitude,
        'status',e.status,'created_at',e.created_at
      )
      order by e.created_at desc
    ),
    '[]'::jsonb
  )
  into v_emergencies
  from public.emergency_events e
  left join public.users u on u.id=e.user_id
  left join public.trips et on et.id=e.trip_id
  left join public.ride_requests er on er.id=et.ride_request_id
  left join public.delivery_requests ed on ed.id=e.delivery_id
  left join lateral (
    select public.service_zone_id_for_point(
      ed.pickup_latitude::numeric,
      ed.pickup_longitude::numeric
    ) as zone_id
  ) edz on true
  left join public.service_zones ez
    on ez.id=coalesce(er.zone_id,edz.zone_id,u.last_zone_id)
  where ez.id=v_zone
    and coalesce(et.channel,ed.channel,v_channel)=v_channel
    and e.status not in ('resolved','closed');

  select coalesce(
    jsonb_agg(item order by ts desc),
    '[]'::jsonb
  )
  into v_activity
  from (
    select
      t.created_at as ts,
      jsonb_build_object(
        'kind','trip','id',t.id,'channel',t.channel,
        'zone_id',rr.zone_id,'country_code',z.country_code,
        'status',t.status,'title','Viaje',
        'subtitle',coalesce(rr.pickup_address,'Origen')||' → '||
                   coalesce(rr.destination_address,'Destino'),
        'created_at',t.created_at
      ) as item
    from public.trips t
    join public.ride_requests rr on rr.id=t.ride_request_id
    left join public.service_zones z on z.id=rr.zone_id
    where t.channel=v_channel and rr.zone_id=v_zone

    union all

    select
      d.created_at,
      jsonb_build_object(
        'kind','delivery','id',d.id,'channel',d.channel,
        'zone_id',z.id,'country_code',z.country_code,
        'status',d.status,'title','Delivery',
        'subtitle',coalesce(d.pickup_address,'Origen')||' → '||
                   coalesce(d.dropoff_address,'Destino'),
        'created_at',d.created_at
      )
    from public.delivery_requests d
    left join lateral (
      select public.service_zone_id_for_point(
        d.pickup_latitude::numeric,
        d.pickup_longitude::numeric
      ) as zone_id
    ) dz on true
    left join public.service_zones z on z.id=dz.zone_id
    where d.channel=v_channel and z.id=v_zone
    order by 1 desc
    limit 30
  ) x;

  select jsonb_build_object(
    'users_total',(
      select count(*)
      from public.users u
      left join public.driver_profiles dp on dp.id=u.id
      left join public.account_runtime_bindings rb on rb.user_id=u.id
      where coalesce(u.last_zone_id,dp.zone_id)=v_zone
        and public.normalize_runtime_channel(
          coalesce(
            rb.environment,
            case when exists(
              select 1
              from public.audit_test_group_members m
              join public.audit_test_groups g on g.id=m.group_id
              where m.user_id=u.id and m.enabled=true and g.active=true
            ) then 'preview' else 'production' end
          )
        )=v_channel
    ),
    'drivers_total',jsonb_array_length(v_drivers),
    'drivers_online',(
      select count(*)
      from jsonb_array_elements(v_drivers) d
      where d->>'online_status'='online'
    ),
    'drivers_pending',(
      select count(*)
      from jsonb_array_elements(v_drivers) d
      where d->>'approval_status'='pending'
    ),
    'ride_searching',(
      select count(*)
      from public.ride_requests r
      where r.channel=v_channel
        and r.zone_id=v_zone
        and r.status in ('searching','offers_received')
        and r.expires_at>v_now
    ),
    'active_trips',jsonb_array_length(v_trips),
    'trips_today',(
      select count(*)
      from public.trips t
      join public.ride_requests r on r.id=t.ride_request_id
      where t.channel=v_channel and r.zone_id=v_zone
        and t.created_at>=v_today
    ),
    'completed_today',(
      select count(*)
      from public.trips t
      join public.ride_requests r on r.id=t.ride_request_id
      where t.channel=v_channel and r.zone_id=v_zone
        and t.status='completed'
        and coalesce(t.completed_at,t.created_at)>=v_today
    ),
    'cancelled_today',(
      select count(*)
      from public.trips t
      join public.ride_requests r on r.id=t.ride_request_id
      where t.channel=v_channel and r.zone_id=v_zone
        and t.status='cancelled' and t.created_at>=v_today
    ) + (
      select count(*)
      from public.ride_requests r
      where r.channel=v_channel and r.zone_id=v_zone
        and r.status='cancelled' and r.created_at>=v_today
    ),
    'delivery_searching',(
      select count(*)
      from public.delivery_requests d
      left join lateral (
        select public.service_zone_id_for_point(
          d.pickup_latitude::numeric,
          d.pickup_longitude::numeric
        ) as zone_id
      ) dz on true
      where d.channel=v_channel and dz.zone_id=v_zone
        and d.status='searching'
    ),
    'active_deliveries',jsonb_array_length(v_deliveries),
    'deliveries_today',(
      select count(*)
      from public.delivery_requests d
      left join lateral (
        select public.service_zone_id_for_point(
          d.pickup_latitude::numeric,
          d.pickup_longitude::numeric
        ) as zone_id
      ) dz on true
      where d.channel=v_channel and dz.zone_id=v_zone
        and d.created_at>=v_today
    ),
    'completed_deliveries_today',(
      select count(*)
      from public.delivery_requests d
      left join lateral (
        select public.service_zone_id_for_point(
          d.pickup_latitude::numeric,
          d.pickup_longitude::numeric
        ) as zone_id
      ) dz on true
      where d.channel=v_channel and dz.zone_id=v_zone
        and d.status='delivered'
        and coalesce(d.completed_at,d.created_at)>=v_today
    ),
    'open_emergencies',jsonb_array_length(v_emergencies)
  )
  into v_metrics;

  return jsonb_build_object(
    'metrics',v_metrics,
    'drivers',v_drivers,
    'active_trips',v_trips,
    'active_deliveries',v_deliveries,
    'emergencies',v_emergencies,
    'activity',v_activity,
    'generated_at',v_now
  );
end;
$function$;

-- admin_delivery_list_v4
CREATE OR REPLACE FUNCTION public.admin_delivery_list_v4(p_channel text DEFAULT 'production'::text, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_zone_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
begin
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    from (
      select
        d.id,d.status,d.proposed_fare,d.currency,d.payment_method,
        d.created_at,d.completed_at,d.channel,
        cu.full_name as customer_name,du.full_name as courier_name,
        d.pickup_address,d.dropoff_address,d.package_type,
        z.id as zone_id,z.zone_key,z.name as zone_name,z.city,
        z.region_department,z.country,z.country_code
      from public.delivery_requests d
      left join public.users cu on cu.id=d.customer_id
      left join public.users du on du.id=d.courier_id
      left join lateral (
        select public.service_zone_id_for_point(
          d.pickup_latitude::numeric,
          d.pickup_longitude::numeric
        ) as zone_id
      ) dz on true
      left join public.service_zones z on z.id=dz.zone_id
      where d.channel=v_channel
        and z.id=v_zone
        and (p_from is null or d.created_at>=p_from)
        and (p_to is null or d.created_at<p_to)
        and (p_status is null or p_status='' or d.status=p_status)
      order by d.created_at desc
      limit greatest(1,least(coalesce(p_limit,100),500))
      offset greatest(0,coalesce(p_offset,0))
    ) x
  );
end;
$function$;

-- admin_driver_detail_v2
CREATE OR REPLACE FUNCTION public.admin_driver_detail_v2(p_user_id uuid, p_channel text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_assert_target_environment(p_user_id,p_channel);
  return public.admin_driver_detail(p_user_id);
end;
$function$;

-- admin_driver_list_v3
CREATE OR REPLACE FUNCTION public.admin_driver_list_v3(p_channel text DEFAULT 'production'::text, p_zone_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
begin
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id',d.id,
          'full_name',u.full_name,
          'email',au.email,
          'phone',u.phone,
          'approval_status',d.approval_status,
          'online_status',d.online_status,
          'license_number',d.license_number,
          'vehicle_summary',d.vehicle_summary,
          'city',d.city,
          'rating',d.rating,
          'completed_trips',d.completed_trips,
          'zone_id',d.zone_id,
          'zone_key',z.zone_key,
          'zone_name',z.name,
          'country',z.country,
          'country_code',z.country_code,
          'currency_code',z.currency_code,
          'latitude',d.latitude,
          'longitude',d.longitude,
          'heading_degrees',d.heading_degrees,
          'location_updated_at',d.location_updated_at,
          'is_qa',
            (
              exists(
                select 1
                from public.audit_test_group_members m
                join public.audit_test_groups g on g.id=m.group_id
                where m.user_id=d.id and m.enabled=true and g.active=true
              )
              or lower(coalesce(au.email,'')) like 'qa-%@expressdelivery.pro'
              or lower(coalesce(u.full_name,'')) like 'qa %'
            ),
          'created_at',d.created_at
        )
        order by
          case d.approval_status
            when 'pending' then 0
            when 'approved' then 1
            else 2
          end,
          d.created_at desc
      ),
      '[]'::jsonb
    )
    from public.driver_profiles d
    join public.users u on u.id=d.id
    left join auth.users au on au.id=d.id
    left join public.service_zones z on z.id=d.zone_id
    left join public.account_runtime_bindings rb on rb.user_id=d.id
    where d.zone_id=v_zone
      and public.normalize_runtime_channel(
        coalesce(
          rb.environment,
          case when exists(
            select 1
            from public.audit_test_group_members m
            join public.audit_test_groups g on g.id=m.group_id
            where m.user_id=d.id and m.enabled=true and g.active=true
          ) then 'preview' else 'production' end
        )
      )=v_channel
  );
end;
$function$;

-- admin_marketplace_orders_v2
CREATE OR REPLACE FUNCTION public.admin_marketplace_orders_v2(p_channel text DEFAULT 'production'::text, p_zone_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
begin
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    from (
      select
        o.id,o.channel,o.status,o.payment_method,o.payment_status,
        o.currency_code,o.total_amount,o.driver_payout,
        o.tip_amount,o.express_margin,o.created_at,
        o.transfer_receipt_url,o.transfer_submitted_at,
        o.zone_id,m.name as merchant_name,
        z.zone_key,z.name as zone_name,z.country,z.country_code
      from public.marketplace_orders o
      join public.marketplace_merchants m on m.id=o.merchant_id
      join public.service_zones z on z.id=o.zone_id
      where o.channel=v_channel
        and o.zone_id=v_zone
      order by o.created_at desc
      limit greatest(1,least(coalesce(p_limit,100),500))
    ) x
  );
end;
$function$;

-- admin_trip_detail_v2
CREATE OR REPLACE FUNCTION public.admin_trip_detail_v2(p_trip_id uuid, p_channel text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text := public.admin_assert_environment(p_channel);
  v_trip_channel text;
begin
  select lower(coalesce(nullif(trim(t.channel),''),'production'))
  into v_trip_channel
  from public.trips t
  where t.id=p_trip_id;

  if v_trip_channel is null then
    raise exception 'Viaje no encontrado';
  end if;
  if v_trip_channel <> v_channel then
    raise exception 'El viaje pertenece a % y el panel está en %',v_trip_channel,v_channel;
  end if;

  return public.admin_trip_detail(p_trip_id);
end;
$function$;

-- admin_trip_list_v4
CREATE OR REPLACE FUNCTION public.admin_trip_list_v4(p_channel text DEFAULT 'production'::text, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_zone_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
begin
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    from (
      select
        t.id,t.status,t.final_fare,t.payment_status,t.created_at,t.completed_at,
        t.channel,
        pu.full_name as passenger_name,du.full_name as driver_name,
        rr.pickup_address,rr.destination_address,rr.category,rr.currency,
        rr.payment_method,rr.zone_id,z.name as zone_name,z.city,
        z.region_department,z.country,z.country_code
      from public.trips t
      join public.ride_requests rr on rr.id=t.ride_request_id
      left join public.users pu on pu.id=t.passenger_id
      left join public.users du on du.id=t.driver_id
      left join public.service_zones z on z.id=rr.zone_id
      where t.channel=v_channel
        and rr.channel=v_channel
        and rr.zone_id=v_zone
        and (p_from is null or t.created_at>=p_from)
        and (p_to is null or t.created_at<p_to)
        and (p_status is null or p_status='' or t.status=p_status)
      order by t.created_at desc
      limit greatest(1,least(coalesce(p_limit,100),500))
      offset greatest(0,coalesce(p_offset,0))
    ) x
  );
end;
$function$;

-- admin_update_user_profile_v2
CREATE OR REPLACE FUNCTION public.admin_update_user_profile_v2(p_user_id uuid, p_full_name text, p_phone text, p_active_mode text, p_account_status text, p_zone_id uuid, p_channel text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_result jsonb;
begin
  perform public.admin_assert_target_environment(p_user_id,p_channel);
  v_result := public.admin_update_user_profile(
    p_user_id,p_full_name,p_phone,p_active_mode,p_account_status,p_zone_id
  );
  perform public.admin_log_action(
    'admin_scope_confirmed','user',p_user_id::text,
    jsonb_build_object('environment',lower(trim(p_channel)))
  );
  return v_result;
end;
$function$;

-- admin_user_detail_v2
CREATE OR REPLACE FUNCTION public.admin_user_detail_v2(p_user_id uuid, p_channel text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_assert_target_environment(p_user_id,p_channel);
  return public.admin_user_detail(p_user_id);
end;
$function$;

-- admin_user_list_v4
CREATE OR REPLACE FUNCTION public.admin_user_list_v4(p_channel text DEFAULT 'production'::text, p_zone_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
  v_search text:=lower(trim(coalesce(p_search,'')));
begin
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    from (
      select
        u.id as user_id,u.full_name,au.email,u.phone,u.active_mode,u.account_status,
        d.approval_status as driver_status,
        coalesce(u.last_zone_id,d.zone_id) as zone_id,
        z.zone_key,z.name as zone_name,z.city,z.region_department,
        z.country,z.country_code,u.created_at,
        (v_channel='preview') as is_qa
      from public.users u
      left join auth.users au on au.id=u.id
      left join public.driver_profiles d on d.id=u.id
      left join public.service_zones z on z.id=coalesce(u.last_zone_id,d.zone_id)
      left join public.account_runtime_bindings rb on rb.user_id=u.id
      where z.id=v_zone
        and public.normalize_runtime_channel(
          coalesce(
            rb.environment,
            case when exists(
              select 1
              from public.audit_test_group_members m
              join public.audit_test_groups g on g.id=m.group_id
              where m.user_id=u.id and m.enabled=true and g.active=true
            ) then 'preview' else 'production' end
          )
        )=v_channel
        and (
          v_search='' or
          lower(coalesce(u.full_name,'')) like '%'||v_search||'%' or
          lower(coalesce(au.email,'')) like '%'||v_search||'%' or
          lower(coalesce(u.phone,'')) like '%'||v_search||'%'
        )
      order by u.created_at desc
      limit greatest(1,least(coalesce(p_limit,100),500))
      offset greatest(0,coalesce(p_offset,0))
    ) x
  );
end;
$function$;

drop function if exists public.admin_operator_trip_detail(uuid);
drop function if exists public.admin_operator_user_detail(uuid);
drop function if exists public.admin_operator_driver_detail(uuid);
drop function if exists public.admin_operator_merchant_detail(uuid);
drop function if exists public.admin_operator_partner_detail(uuid);
drop function if exists public.admin_operator_update_contact(text,uuid,text,text);
drop function if exists public.admin_operator_assert_record(text,text,uuid);
drop function if exists public.admin_operator_assert_module(text);

commit;
