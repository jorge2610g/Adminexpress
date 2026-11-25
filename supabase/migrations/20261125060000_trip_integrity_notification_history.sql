-- Move trip integrity alerts out of general Notices and expose a scoped history
-- inside the suspicious trips module.
begin;

create or replace function public.admin_announcement_list_v1(
  p_channel text,
  p_zone_id uuid,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_op boolean;
begin
  p_zone_id := public.admin_comm_scope(p_channel, p_zone_id, false);
  v_op := public.admin_zone_role_now() = 'operator';
  if p_zone_id is null then return '[]'::jsonb; end if;

  return coalesce((
    with individual_notices as (
      select n.id, n.title, n.body, n.is_read, n.channel, n.created_at,
             n.metadata, u.full_name as recipient_name,
             case
               when n.metadata->>'kind' like 'trip_integrity_%' then 'drivers'
               when n.metadata->>'audience' in ('drivers', 'passengers', 'all')
                 then n.metadata->>'audience'
               when u.active_mode = 'driver' then 'drivers'
               else 'passengers'
             end as audience,
             coalesce(
               case when n.metadata->>'zone_id' ~* '^[0-9a-f-]{36}$'
                 then (n.metadata->>'zone_id')::uuid end,
               case when n.metadata->>'kind' like 'trip_integrity_%' then dp.zone_id
                    when u.active_mode = 'driver' then dp.zone_id
                    else u.last_zone_id end
             ) as zone_id
        from public.notifications n
        join public.users u on u.id = n.user_id
        left join public.driver_profiles dp on dp.id = u.id
       where n.type = 'admin_announcement'
         and n.campaign_id is null
         and not (coalesce(n.metadata, '{}'::jsonb) ? 'managed_announcement_id')
         and n.channel = v_channel
         and left(coalesce(n.metadata->>'kind', ''), 15) <> 'trip_integrity_'
    ), rows as (
      select a.id, a.category, a.title, a.body, a.image_url, a.audience,
             a.zone_id, z.name as zone_name, a.partner_id, a.status,
             a.publish_at, a.expires_at, a.created_at, a.push_campaign_id,
             (a.push_campaign_id is not null) as with_push,
             case when a.status = 'published' and a.publish_at <= now()
                            and (a.expires_at is null or a.expires_at > now())
                    then 'visible'
                  when a.status = 'published' and a.publish_at > now() then 'programado'
                  when a.status = 'published' then 'vencido'
                  else a.status end as state,
             (select count(*) from public.announcement_reads r
               where r.announcement_id = a.id)::int as read_count,
             (select count(*) from public.users u
               where public.announcement_matches_user(a, u.id))::int as audience_size,
             c.recipients_targeted as push_recipients,
             false as is_individual,
             null::text as recipient_name
        from public.announcements a
        left join public.service_zones z on z.id = a.zone_id
        left join public.notification_campaigns c on c.id = a.push_campaign_id
       where a.channel = v_channel
         and ((v_op and a.zone_id = p_zone_id)
           or (not v_op and (a.zone_id is null or a.zone_id = p_zone_id)))

      union all

      select n.id,
             'importante'::text as category,
             n.title,
             n.body,
             null::text as image_url,
             n.audience,
             n.zone_id,
             z.name as zone_name,
             null::uuid as partner_id,
             'individual'::text as status,
             n.created_at as publish_at,
             null::timestamptz as expires_at,
             n.created_at,
             null::uuid as push_campaign_id,
             false as with_push,
             'individual'::text as state,
             case when n.is_read then 1 else 0 end as read_count,
             1 as audience_size,
             null::integer as push_recipients,
             true as is_individual,
             n.recipient_name
        from individual_notices n
        left join public.service_zones z on z.id = n.zone_id
       where (v_op and n.zone_id = p_zone_id)
          or (not v_op and (n.zone_id is null or n.zone_id = p_zone_id))
    )
    select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (select * from rows
             order by created_at desc
             limit greatest(1, least(coalesce(p_limit, 100), 300))) x
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_announcement_list_v1(text, uuid, integer) from public, anon;
grant execute on function public.admin_announcement_list_v1(text, uuid, integer) to authenticated;

commit;


begin;

create or replace function public.admin_trip_integrity_notifications(
  p_zone_id uuid, p_channel text, p_limit integer default 500
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare v_context jsonb;
begin
  if auth.uid() is null or not public.is_admin()
     or p_channel not in ('preview','production')
     or not public.admin_environment_allowed(p_channel) then
    raise exception 'Acceso a notificaciones de viajes sospechosos no autorizado';
  end if;
  if p_zone_id is null then return '[]'::jsonb; end if;
  v_context := public.admin_access_context();
  if v_context->>'zone_id' is not null
     and (v_context->>'zone_id')::uuid <> p_zone_id then
    raise exception 'Zona administrativa no autorizada';
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select n.id, n.user_id as driver_id,
               coalesce(nullif(trim(u.full_name), ''), 'Conductor') as driver_name,
               n.title, n.body, n.metadata->>'kind' as alert_kind,
               n.metadata->>'trip_id' as trip_id, n.is_read, n.created_at,
               dp.zone_id, z.name as zone_name, p_channel as channel
          from public.notifications n
          join public.users u on u.id = n.user_id
          join public.driver_profiles dp on dp.id = u.id
          left join public.service_zones z on z.id = dp.zone_id
         where n.type = 'admin_announcement'
           and left(coalesce(n.metadata->>'kind', ''), 15) = 'trip_integrity_'
           and n.metadata->>'kind' <> 'trip_integrity_admin_alert'
           and dp.zone_id = p_zone_id
           and coalesce((select b.environment from public.account_runtime_bindings b
                          where b.user_id = u.id), 'production') = p_channel
           and coalesce(nullif(n.metadata->>'channel', ''), n.channel, 'production') = p_channel
         order by n.created_at desc
         limit greatest(1, least(coalesce(p_limit, 500), 1000))
      ) x
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_trip_integrity_notifications(uuid, text, integer) from public, anon;
grant execute on function public.admin_trip_integrity_notifications(uuid, text, integer) to authenticated;
commit;
