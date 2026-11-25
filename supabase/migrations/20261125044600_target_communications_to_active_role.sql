-- A dual-role account belongs to the role that is currently active in the app.
-- This keeps driver-only announcements and live meetings out of its passenger view.
begin;

create or replace function public.announcement_matches_user(a public.announcements, p_user uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.users u
    left join public.driver_profiles dp on dp.id = u.id
    where u.id = p_user and u.account_status = 'active'
      and (a.audience = 'all'
           or (a.audience = 'drivers' and u.active_mode = 'driver'
               and dp.id is not null and dp.approval_status = 'approved')
           or (a.audience = 'passengers' and u.active_mode = 'passenger'))
      and (a.zone_id is null or (case
             when a.audience = 'drivers' then dp.zone_id
             when a.audience = 'passengers' then u.last_zone_id
             when dp.id is not null and dp.approval_status = 'approved' then dp.zone_id
             else u.last_zone_id end) = a.zone_id)
      and (a.partner_id is null or exists (
             select 1 from public.driver_partner_memberships m
              where m.driver_id = u.id and m.partner_id = a.partner_id and m.status = 'active'))
      and public.comm_user_in_channel(u.id, a.channel));
$$;
revoke all on function public.announcement_matches_user(public.announcements, uuid) from public, anon, authenticated;

create or replace function public.live_meeting_matches_user(m public.live_meetings, p_user uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.users u
    left join public.driver_profiles dp on dp.id = u.id
    where u.id = p_user and u.account_status = 'active'
      and (m.audience = 'all'
           or (m.audience = 'drivers' and u.active_mode = 'driver'
               and dp.id is not null and dp.approval_status = 'approved')
           or (m.audience = 'passengers' and u.active_mode = 'passenger'))
      and (m.zone_id is null or (case
             when m.audience = 'drivers' then dp.zone_id
             when m.audience = 'passengers' then u.last_zone_id
             when dp.id is not null and dp.approval_status = 'approved' then dp.zone_id
             else u.last_zone_id end) = m.zone_id)
      and public.comm_user_in_channel(u.id, m.channel));
$$;
revoke all on function public.live_meeting_matches_user(public.live_meetings, uuid) from public, anon, authenticated;

do $migration$
declare
  d text;
  old_drivers text;
  new_drivers text;
  old_passengers text;
  new_passengers text;
begin
  -- The current push endpoint targets users, so use their active app role.
  d := pg_get_functiondef('public.admin_send_push_v1(text,text,text,text,text,uuid,uuid,uuid)'::regprocedure);
  old_drivers := 'or (p_audience = ''drivers'' and dp.id is not null and dp.approval_status = ''approved'')';
  new_drivers := 'or (p_audience = ''drivers'' and u.active_mode = ''driver'' and dp.id is not null and dp.approval_status = ''approved'')';
  old_passengers := 'or (p_audience = ''passengers'' and (u.active_mode = ''passenger'' or dp.id is null or dp.approval_status <> ''approved''))';
  new_passengers := 'or (p_audience = ''passengers'' and u.active_mode = ''passenger'')';
  d := replace(d, old_drivers, new_drivers);
  d := replace(d, old_passengers, new_passengers);
  if position(new_drivers in d) = 0 or position(new_passengers in d) = 0 then
    raise exception 'No se pudo aplicar el filtro de audiencia a admin_send_push_v1';
  end if;
  execute d;

  -- Keep the older direct announcement endpoint consistent for existing panels.
  d := pg_get_functiondef('public.admin_send_announcement_v4(text,text,text,text,uuid,uuid)'::regprocedure);
  old_drivers := 'or (p_audience=''drivers'' and dp.id is not null and dp.approval_status=''approved'')';
  new_drivers := 'or (p_audience=''drivers'' and u.active_mode=''driver'' and dp.id is not null and dp.approval_status=''approved'')';
  old_passengers := 'or (p_audience=''passengers'' and (u.active_mode=''passenger'' or dp.id is null or dp.approval_status<>''approved''))';
  new_passengers := 'or (p_audience=''passengers'' and u.active_mode=''passenger'')';
  d := replace(d, old_drivers, new_drivers);
  d := replace(d, old_passengers, new_passengers);
  if position(new_drivers in d) = 0 or position(new_passengers in d) = 0 then
    raise exception 'No se pudo aplicar el filtro de audiencia a admin_send_announcement_v4';
  end if;
  execute d;
end;
$migration$;

commit;
