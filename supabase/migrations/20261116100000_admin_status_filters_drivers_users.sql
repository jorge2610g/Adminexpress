-- Filtros de estado en las listas de Conductores y Usuarios del panel.
--
-- Son versiones nuevas (v5 / v2) de admin_driver_list_v4, admin_driver_count_v1,
-- admin_user_list_v4 y admin_user_count_v1, con un parámetro de estado opcional.
-- Las versiones anteriores no se tocan, así que las versiones de la app que
-- todavía las llamen siguen funcionando. Solo lectura, mismos controles de
-- módulo, entorno y zona.
--
-- Conductores (driver_profiles.approval_status): pending, approved, rejected, suspended.
-- Usuarios: 'blocked' y 'suspended' filtran users.account_status;
--           'rejected' filtra la solicitud de conductor rechazada.
-- Sin estado (null o '') devuelve lo mismo que las versiones anteriores.

create or replace function public.admin_driver_list_v5(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0,
  p_status text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
  v_status text := lower(trim(coalesce(p_status, '')));
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
        and (v_status = '' or d.approval_status = v_status)
      order by ord
      limit greatest(1, least(coalesce(p_limit, 50), 500))
      offset greatest(0, coalesce(p_offset, 0))
    ) x
  );
end;
$function$;

create or replace function public.admin_driver_count_v2(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null,
  p_status text default null
)
returns integer
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
  v_status text := lower(trim(coalesce(p_status, '')));
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
      and (v_status = '' or d.approval_status = v_status)
  );
end;
$function$;

create or replace function public.admin_user_list_v5(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0,
  p_status text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
  v_status text := lower(trim(coalesce(p_status, '')));
begin
  perform public.admin_operator_assert_module('users');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
    from (
      select
        u.id as user_id, u.full_name, au.email, u.phone, u.active_mode, u.account_status,
        d.approval_status as driver_status,
        coalesce(u.last_zone_id, d.zone_id) as zone_id,
        z.zone_key, z.name as zone_name, z.city, z.region_department,
        z.country, z.country_code, u.created_at,
        (v_channel = 'preview') as is_qa
      from public.users u
      left join auth.users au on au.id = u.id
      left join public.driver_profiles d on d.id = u.id
      left join public.service_zones z on z.id = coalesce(u.last_zone_id, d.zone_id)
      left join public.account_runtime_bindings rb on rb.user_id = u.id
      where z.id = v_zone
        and public.normalize_runtime_channel(
          coalesce(
            rb.environment,
            case when exists(
              select 1
              from public.audit_test_group_members m
              join public.audit_test_groups g on g.id = m.group_id
              where m.user_id = u.id and m.enabled = true and g.active = true
            ) then 'preview' else 'production' end
          )
        ) = v_channel
        and (
          v_search = '' or
          lower(coalesce(u.full_name, '')) like '%' || v_search || '%' or
          lower(coalesce(au.email, '')) like '%' || v_search || '%' or
          lower(coalesce(u.phone, '')) like '%' || v_search || '%'
        )
        and (
          v_status = '' or
          (v_status in ('blocked', 'suspended') and u.account_status = v_status) or
          (v_status = 'rejected' and d.approval_status = 'rejected')
        )
      order by u.created_at desc
      limit greatest(1, least(coalesce(p_limit, 100), 500))
      offset greatest(0, coalesce(p_offset, 0))
    ) x
  );
end;
$function$;

create or replace function public.admin_user_count_v2(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null,
  p_status text default null
)
returns integer
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
  v_status text := lower(trim(coalesce(p_status, '')));
begin
  perform public.admin_operator_assert_module('users');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select count(*)::integer
    from public.users u
    left join auth.users au on au.id = u.id
    left join public.driver_profiles d on d.id = u.id
    left join public.service_zones z on z.id = coalesce(u.last_zone_id, d.zone_id)
    left join public.account_runtime_bindings rb on rb.user_id = u.id
    where z.id = v_zone
      and public.normalize_runtime_channel(
        coalesce(
          rb.environment,
          case when exists(
            select 1
            from public.audit_test_group_members m
            join public.audit_test_groups g on g.id = m.group_id
            where m.user_id = u.id and m.enabled = true and g.active = true
          ) then 'preview' else 'production' end
        )
      ) = v_channel
      and (
        v_search = '' or
        lower(coalesce(u.full_name, '')) like '%' || v_search || '%' or
        lower(coalesce(au.email, '')) like '%' || v_search || '%' or
        lower(coalesce(u.phone, '')) like '%' || v_search || '%'
      )
      and (
        v_status = '' or
        (v_status in ('blocked', 'suspended') and u.account_status = v_status) or
        (v_status = 'rejected' and d.approval_status = 'rejected')
      )
  );
end;
$function$;

revoke all on function public.admin_driver_list_v5(text, uuid, text, integer, integer, text) from public, anon;
revoke all on function public.admin_driver_count_v2(text, uuid, text, text) from public, anon;
revoke all on function public.admin_user_list_v5(text, uuid, text, integer, integer, text) from public, anon;
revoke all on function public.admin_user_count_v2(text, uuid, text, text) from public, anon;
grant execute on function public.admin_driver_list_v5(text, uuid, text, integer, integer, text) to authenticated, service_role;
grant execute on function public.admin_driver_count_v2(text, uuid, text, text) to authenticated, service_role;
grant execute on function public.admin_user_list_v5(text, uuid, text, integer, integer, text) to authenticated, service_role;
grant execute on function public.admin_user_count_v2(text, uuid, text, text) to authenticated, service_role;
