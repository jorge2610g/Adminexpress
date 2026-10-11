-- Live operations map: expose last known driver location through the
-- existing channel/zone-scoped admin driver RPC.
-- Backward compatible: only additive JSON keys are introduced.

create or replace function public.admin_driver_list_v3(
  p_channel text default 'production'::text,
  p_zone_id uuid default null::uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text:=public.normalize_runtime_channel(p_channel);
  v_zone uuid:=public.admin_effective_zone_id(p_zone_id);
begin
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
