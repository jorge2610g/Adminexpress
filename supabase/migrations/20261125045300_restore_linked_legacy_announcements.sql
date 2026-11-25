-- Repair linked legacy cards if an earlier process removed the editorial row.
begin;

with legacy as (
  select nullif(n.metadata->>'managed_announcement_id', '')::uuid as id,
         n.channel,
         coalesce(nullif(n.metadata->>'audience', ''), 'all') as audience,
         nullif(n.metadata->>'zone_id', '')::uuid as zone_id,
         n.title,
         n.body,
         min(n.created_at) as published_at
    from public.notifications n
   where n.type = 'admin_announcement'
     and n.campaign_id is null
     and n.metadata->>'campaign' = 'true'
     and n.metadata ? 'managed_announcement_id'
   group by n.metadata->>'managed_announcement_id', n.channel,
            n.metadata->>'audience', n.metadata->>'zone_id', n.title, n.body
)
insert into public.announcements (
  id, channel, category, title, body, audience, zone_id, status,
  publish_at, created_at, updated_at
)
select l.id, l.channel, 'importante', l.title, l.body, l.audience, l.zone_id,
       'published', l.published_at, l.published_at, l.published_at
  from legacy l
 where not exists (select 1 from public.announcements a where a.id = l.id)
on conflict (id) do nothing;

insert into public.announcement_reads (announcement_id, user_id)
select a.id, n.user_id
  from public.announcements a
  join public.notifications n
    on n.metadata->>'managed_announcement_id' = a.id::text
 where n.type = 'admin_announcement'
   and n.is_read
on conflict do nothing;

commit;
