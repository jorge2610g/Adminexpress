-- Paginación en el servidor para el panel: el panel pide 50 filas por vez y
-- muestra el total exacto. Mismos permisos y filtros que las listas actuales.

create or replace function public.admin_trip_count_v1(
  p_channel text default 'production',
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_zone_id uuid default null,
  p_status text default null
)
returns integer
language plpgsql stable security definer
set search_path to 'public'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
begin
  perform public.admin_operator_assert_module('trips');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select count(*)::integer
    from public.trips t
    join public.ride_requests rr on rr.id = t.ride_request_id
    where t.channel = v_channel
      and rr.channel = v_channel
      and rr.zone_id = v_zone
      and (p_from is null or t.created_at >= p_from)
      and (p_to is null or t.created_at < p_to)
      and (p_status is null or p_status = '' or t.status = p_status)
  );
end;
$function$;

create or replace function public.admin_delivery_count_v1(
  p_channel text default 'production',
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_zone_id uuid default null,
  p_status text default null
)
returns integer
language plpgsql stable security definer
set search_path to 'public'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
begin
  perform public.admin_operator_assert_module('delivery');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select count(*)::integer
    from public.delivery_requests d
    where d.channel = v_channel
      and public.service_zone_id_for_point(
        d.pickup_latitude::numeric, d.pickup_longitude::numeric
      ) = v_zone
      and (p_from is null or d.created_at >= p_from)
      and (p_to is null or d.created_at < p_to)
      and (p_status is null or p_status = '' or d.status = p_status)
  );
end;
$function$;

-- Conductores: misma información que admin_driver_list_v3, pero por páginas
-- y con búsqueda por nombre, correo o teléfono.
create or replace function public.admin_driver_list_v4(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql stable security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
begin
  perform public.admin_operator_assert_module('drivers');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(jsonb_agg(x.row order by x.ord), '[]'::jsonb)
    from (
      select
        row_number() over (
          order by
            case d.approval_status when 'pending' then 0 when 'approved' then 1 else 2 end,
            d.created_at desc
        ) as ord,
        jsonb_build_object(
          'user_id', d.id,
          'full_name', u.full_name,
          'email', au.email,
          'phone', u.phone,
          'approval_status', d.approval_status,
          'online_status', d.online_status,
          'license_number', d.license_number,
          'vehicle_summary', d.vehicle_summary,
          'city', d.city,
          'rating', d.rating,
          'completed_trips', d.completed_trips,
          'zone_id', d.zone_id,
          'zone_key', z.zone_key,
          'zone_name', z.name,
          'country', z.country,
          'country_code', z.country_code,
          'currency_code', z.currency_code,
          'latitude', d.latitude,
          'longitude', d.longitude,
          'heading_degrees', d.heading_degrees,
          'location_updated_at', d.location_updated_at,
          'is_qa',
            (
              exists(
                select 1
                from public.audit_test_group_members m
                join public.audit_test_groups g on g.id = m.group_id
                where m.user_id = d.id and m.enabled = true and g.active = true
              )
              or lower(coalesce(au.email, '')) like 'qa-%@expressdelivery.pro'
              or lower(coalesce(u.full_name, '')) like 'qa %'
            ),
          'created_at', d.created_at
        ) as row
      from public.driver_profiles d
      join public.users u on u.id = d.id
      left join auth.users au on au.id = d.id
      left join public.service_zones z on z.id = d.zone_id
      left join public.account_runtime_bindings rb on rb.user_id = d.id
      where d.zone_id = v_zone
        and public.normalize_runtime_channel(
          coalesce(
            rb.environment,
            case when exists(
              select 1
              from public.audit_test_group_members m
              join public.audit_test_groups g on g.id = m.group_id
              where m.user_id = d.id and m.enabled = true and g.active = true
            ) then 'preview' else 'production' end
          )
        ) = v_channel
        and (
          v_search = '' or
          lower(coalesce(u.full_name, '')) like '%' || v_search || '%' or
          lower(coalesce(au.email, '')) like '%' || v_search || '%' or
          lower(coalesce(u.phone, '')) like '%' || v_search || '%'
        )
      order by ord
      limit greatest(1, least(coalesce(p_limit, 50), 500))
      offset greatest(0, coalesce(p_offset, 0))
    ) x
  );
end;
$function$;

create or replace function public.admin_driver_count_v1(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null
)
returns integer
language plpgsql stable security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
begin
  perform public.admin_operator_assert_module('drivers');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select count(*)::integer
    from public.driver_profiles d
    join public.users u on u.id = d.id
    left join auth.users au on au.id = d.id
    left join public.account_runtime_bindings rb on rb.user_id = d.id
    where d.zone_id = v_zone
      and public.normalize_runtime_channel(
        coalesce(
          rb.environment,
          case when exists(
            select 1
            from public.audit_test_group_members m
            join public.audit_test_groups g on g.id = m.group_id
            where m.user_id = d.id and m.enabled = true and g.active = true
          ) then 'preview' else 'production' end
        )
      ) = v_channel
      and (
        v_search = '' or
        lower(coalesce(u.full_name, '')) like '%' || v_search || '%' or
        lower(coalesce(au.email, '')) like '%' || v_search || '%' or
        lower(coalesce(u.phone, '')) like '%' || v_search || '%'
      )
  );
end;
$function$;

revoke all on function public.admin_trip_count_v1(text, timestamptz, timestamptz, uuid, text) from public, anon;
revoke all on function public.admin_delivery_count_v1(text, timestamptz, timestamptz, uuid, text) from public, anon;
revoke all on function public.admin_driver_list_v4(text, uuid, text, integer, integer) from public, anon;
revoke all on function public.admin_driver_count_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_trip_count_v1(text, timestamptz, timestamptz, uuid, text) to authenticated;
grant execute on function public.admin_delivery_count_v1(text, timestamptz, timestamptz, uuid, text) to authenticated;
grant execute on function public.admin_driver_list_v4(text, uuid, text, integer, integer) to authenticated;
grant execute on function public.admin_driver_count_v1(text, uuid, text) to authenticated;
