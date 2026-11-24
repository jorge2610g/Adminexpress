-- Exportación completa de conductores para el panel de administración. Mismos permisos y filtros
-- que admin_driver_list_v5 (módulo «drivers», entorno y zona del administrador u operador), con
-- todos los datos del conductor en una sola fila: contacto, estado, licencia, vehículo, zona,
-- calificación, viajes (completados, cancelados, primero y último), pagos, suscripción e integridad.
create or replace function public.admin_driver_export_v1(
  p_channel text default 'production', p_zone_id uuid default null, p_search text default null,
  p_limit integer default 500, p_offset integer default 0, p_status text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
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
          order by case d.approval_status when 'pending' then 0 when 'approved' then 1 else 2 end,
                   d.created_at desc) as ord,
        jsonb_build_object(
          'user_id', d.id,
          'full_name', u.full_name,
          'email', au.email,
          'phone', u.phone,
          'phone_verified_at', u.phone_verified_at,
          'account_status', u.account_status,
          'approval_status', d.approval_status,
          'online_status', d.online_status,
          'created_at', d.created_at,
          'onboarding_completed_at', d.onboarding_completed_at,
          'license_number', d.license_number,
          'vehicle_summary', d.vehicle_summary,
          'vehicle_type', v.vehicle_type,
          'vehicle_brand', v.brand,
          'vehicle_model', v.model,
          'vehicle_color', v.color,
          'vehicle_plate', v.plate,
          'vehicle_year', v.year,
          'city', d.city,
          'zone_name', z.name,
          'country', z.country,
          'currency_code', z.currency_code,
          'rating', d.rating,
          'completed_trips', coalesce(t.completed, 0),
          'cancelled_trips', coalesce(t.cancelled, 0),
          'first_completed_at', t.first_completed,
          'last_completed_at', t.last_completed,
          'accepted_payment_methods', array_to_string(d.accepted_payment_methods, ', '),
          'subscription_status', s.status,
          'subscription_expires_at', s.expires_at,
          'integrity_warnings', i.warnings_in_cycle,
          'integrity_suspensions', i.suspension_count,
          'integrity_suspended_until', i.suspended_until,
          'location_updated_at', d.location_updated_at
        ) as row
      from public.driver_profiles d
      join public.users u on u.id = d.id
      left join auth.users au on au.id = d.id
      left join public.service_zones z on z.id = d.zone_id
      left join public.account_runtime_bindings rb on rb.user_id = d.id
      left join lateral (
        select dv.* from public.driver_vehicles dv
         where dv.driver_id = d.id order by dv.is_active desc, dv.created_at desc limit 1) v on true
      left join lateral (
        select count(*) filter (where tr.status = 'completed') as completed,
               count(*) filter (where tr.status = 'cancelled') as cancelled,
               min(tr.completed_at) filter (where tr.status = 'completed') as first_completed,
               max(tr.completed_at) filter (where tr.status = 'completed') as last_completed
          from public.trips tr where tr.driver_id = d.id) t on true
      left join lateral (
        select ds.* from public.driver_subscriptions ds
         where ds.driver_id = d.id order by ds.started_at desc nulls last limit 1) s on true
      left join public.driver_integrity_state i on i.driver_id = d.id
      where d.zone_id = v_zone
        and public.normalize_runtime_channel(
          coalesce(
            rb.environment,
            case when exists(
              select 1 from public.audit_test_group_members m
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
      limit greatest(1, least(coalesce(p_limit, 500), 500))
      offset greatest(0, coalesce(p_offset, 0))
    ) x
  );
end;
$$;
revoke all on function public.admin_driver_export_v1(text, uuid, text, integer, integer, text) from public, anon;
grant execute on function public.admin_driver_export_v1(text, uuid, text, integer, integer, text) to authenticated;
