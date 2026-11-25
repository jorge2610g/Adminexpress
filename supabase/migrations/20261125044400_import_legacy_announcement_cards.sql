-- Bring old per-user announcement notifications into the editorial list.
-- These rows were broadcast as notifications before the announcements table
-- became the source of truth, so users could still see them while Admin could not.
begin;

with legacy as (
  select n.channel,
         coalesce(nullif(n.metadata->>'audience', ''), 'all') as audience,
         nullif(n.metadata->>'zone_id', '')::uuid as zone_id,
         n.title,
         n.body,
         min(n.created_at) as published_at
    from public.notifications n
   where n.type = 'admin_announcement'
     and n.campaign_id is null
     and n.metadata->>'campaign' = 'true'
   group by n.channel, n.metadata->>'audience', n.metadata->>'zone_id', n.title, n.body
)
insert into public.announcements (
  channel, category, title, body, audience, zone_id, status,
  publish_at, created_at, updated_at
)
select l.channel, 'importante', l.title, l.body, l.audience, l.zone_id,
       'published', l.published_at, l.published_at, l.published_at
  from legacy l
 where not exists (
   select 1 from public.announcements a
    where a.channel = l.channel
      and a.title = l.title
      and a.body = l.body
      and a.audience = l.audience
      and a.zone_id is not distinct from l.zone_id
 );

insert into public.announcement_reads (announcement_id, user_id)
select a.id, n.user_id
  from public.announcements a
  join public.notifications n
    on n.channel = a.channel
   and n.title = a.title
   and n.body = a.body
   and n.metadata->>'audience' = a.audience
   and nullif(n.metadata->>'zone_id', '')::uuid is not distinct from a.zone_id
 where n.type = 'admin_announcement'
   and n.campaign_id is null
   and n.metadata->>'campaign' = 'true'
   and n.is_read
on conflict do nothing;

update public.notifications n
   set metadata = coalesce(n.metadata, '{}'::jsonb)
                 || jsonb_build_object('managed_announcement_id', a.id::text)
  from public.announcements a
 where n.type = 'admin_announcement'
   and n.campaign_id is null
   and n.metadata->>'campaign' = 'true'
   and n.channel = a.channel
   and n.title = a.title
   and n.body = a.body
   and n.metadata->>'audience' = a.audience
   and nullif(n.metadata->>'zone_id', '')::uuid is not distinct from a.zone_id
   and n.metadata->>'managed_announcement_id' is distinct from a.id::text;

-- The app reads both editorial records and older personal notification rows.
-- Once the historical rows have been imported, suppress their old copies.
create or replace function public.my_announcements_v1(
  p_channel text default 'production',
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_channel text := public.normalize_runtime_channel(p_channel);
begin
  if v_uid is null then raise exception 'Sesión requerida'; end if;
  if not public.comm_user_in_channel(v_uid, v_channel) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(x.j order by x.at desc)
      from (
        select a.publish_at as at,
               jsonb_build_object(
                 'id', a.id, 'kind', 'announcement', 'category', a.category,
                 'title', a.title, 'body', a.body, 'image_url', a.image_url,
                 'buttons', a.buttons,
                 'publish_at', a.publish_at, 'expires_at', a.expires_at,
                 'is_read', exists (
                   select 1 from public.announcement_reads r
                    where r.announcement_id = a.id and r.user_id = v_uid
                 ),
                 'with_push', a.push_campaign_id is not null
               ) as j
          from public.announcements a
         where a.channel = v_channel
           and a.status = 'published'
           and a.publish_at <= now()
           and (a.expires_at is null or a.expires_at > now())
           and public.announcement_matches_user(a, v_uid)
        union all
        select n.created_at,
               jsonb_build_object(
                 'id', n.id, 'kind', 'account', 'category', 'importante',
                 'title', n.title, 'body', n.body, 'image_url', null,
                 'buttons', '[]'::jsonb,
                 'publish_at', n.created_at, 'expires_at', null,
                 'is_read', n.is_read, 'with_push', true
               )
          from public.notifications n
         where n.user_id = v_uid
           and n.type = 'admin_announcement'
           and n.campaign_id is null
           and n.channel = v_channel
           and not (n.metadata ? 'managed_announcement_id')
         order by 1 desc
         limit greatest(1, least(coalesce(p_limit, 100), 300))
      ) x
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.my_announcements_v1(text, integer) from public, anon;
grant execute on function public.my_announcements_v1(text, integer) to authenticated;

create or replace function public.my_announcements_unread_v1(
  p_channel text default 'production'
)
returns integer
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_channel text := public.normalize_runtime_channel(p_channel);
  n integer;
begin
  if v_uid is null then return 0; end if;
  if not public.comm_user_in_channel(v_uid, v_channel) then return 0; end if;
  select
    (select count(*) from public.announcements a
      where a.channel = v_channel and a.status = 'published' and a.publish_at <= now()
        and (a.expires_at is null or a.expires_at > now())
        and public.announcement_matches_user(a, v_uid)
        and not exists (select 1 from public.announcement_reads r
                         where r.announcement_id = a.id and r.user_id = v_uid))
    + (select count(*) from public.notifications nn
        where nn.user_id = v_uid and nn.type = 'admin_announcement'
          and nn.campaign_id is null and nn.channel = v_channel and nn.is_read = false
          and not (nn.metadata ? 'managed_announcement_id'))
    into n;
  return coalesce(n, 0);
end;
$$;
revoke all on function public.my_announcements_unread_v1(text) from public, anon;
grant execute on function public.my_announcements_unread_v1(text) to authenticated;

commit;
