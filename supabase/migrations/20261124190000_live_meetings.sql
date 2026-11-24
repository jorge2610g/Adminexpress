-- «En directo»: reuniones por Google Meet con un círculo parpadeante en la pantalla del conductor.
create table if not exists public.live_meetings (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('preview', 'production')),
  zone_id uuid references public.service_zones(id),
  audience text not null default 'drivers' check (audience in ('drivers', 'passengers', 'all')),
  title text not null check (char_length(title) between 1 and 80),
  message text not null default '' check (char_length(message) <= 300),
  meet_url text not null check (meet_url ~* '^https://meet\.google\.com/[A-Za-z0-9_?=&./-]+$' and char_length(meet_url) <= 300),
  active boolean not null default true,
  started_at timestamptz not null default now(),
  ends_at timestamptz,
  ended_at timestamptz,
  created_by uuid references public.users(id) on delete set null
);
create unique index if not exists live_meetings_one_active
  on public.live_meetings (channel, coalesce(zone_id, '00000000-0000-0000-0000-000000000000'::uuid)) where active;
create table if not exists public.live_meeting_joins (
  meeting_id uuid not null references public.live_meetings(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (meeting_id, user_id)
);
alter table public.live_meetings enable row level security;
alter table public.live_meeting_joins enable row level security;

create or replace function public.live_meeting_matches_user(m public.live_meetings, p_user uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.users u
    left join public.driver_profiles dp on dp.id = u.id
    where u.id = p_user and u.account_status = 'active'
      and (m.audience = 'all'
           or (m.audience = 'drivers' and dp.id is not null and dp.approval_status = 'approved')
           or (m.audience = 'passengers' and (u.active_mode = 'passenger' or dp.id is null or dp.approval_status <> 'approved')))
      and (m.zone_id is null or (case
             when m.audience = 'drivers' then dp.zone_id
             when m.audience = 'passengers' then u.last_zone_id
             when dp.id is not null and dp.approval_status = 'approved' then dp.zone_id
             else u.last_zone_id end) = m.zone_id)
      and public.comm_user_in_channel(u.id, m.channel));
$$;
revoke all on function public.live_meeting_matches_user(public.live_meetings, uuid) from public, anon, authenticated;

-- Cierra las reuniones que ya pasaron su hora.
create or replace function public.live_meetings_expire()
returns void language sql security definer set search_path to 'public' as $$
  update public.live_meetings set active = false, ended_at = coalesce(ended_at, now())
   where active and ends_at is not null and ends_at <= now();
$$;
revoke all on function public.live_meetings_expire() from public, anon, authenticated;

create or replace function public.admin_live_meeting_get_v1(p_channel text, p_zone_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_zone uuid; m public.live_meetings%rowtype;
begin
  v_zone := public.admin_comm_scope(p_channel, p_zone_id, false);
  perform public.live_meetings_expire();
  select * into m from public.live_meetings
   where channel = public.normalize_runtime_channel(p_channel) and zone_id is not distinct from v_zone
   order by active desc, started_at desc limit 1;
  if m.id is null then return null; end if;
  return to_jsonb(m) || jsonb_build_object('joins', (select count(*) from public.live_meeting_joins j where j.meeting_id = m.id));
end $$;
revoke all on function public.admin_live_meeting_get_v1(text, uuid) from public, anon;
grant execute on function public.admin_live_meeting_get_v1(text, uuid) to authenticated;

create or replace function public.admin_live_meeting_save_v1(
  p_channel text, p_zone_id uuid, p_title text, p_message text, p_meet_url text,
  p_audience text, p_ends_at timestamptz, p_send_push boolean default false)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_zone uuid; v_id uuid;
  v_title text := trim(coalesce(p_title, '')); v_msg text := trim(coalesce(p_message, '')); v_push jsonb;
begin
  v_zone := public.admin_comm_scope(p_channel, p_zone_id, true);
  if p_audience not in ('drivers', 'passengers', 'all') then raise exception 'Audiencia inválida'; end if;
  if char_length(v_title) < 1 or char_length(v_title) > 80 then raise exception 'Escribe un título (máximo 80 caracteres)'; end if;
  if char_length(v_msg) > 300 then raise exception 'El mensaje admite hasta 300 caracteres'; end if;
  if trim(coalesce(p_meet_url, '')) !~* '^https://meet\.google\.com/[A-Za-z0-9_?=&./-]+$' then
    raise exception 'El enlace debe ser de Google Meet (https://meet.google.com/...)';
  end if;
  if p_ends_at is not null and p_ends_at <= now() then raise exception 'La hora de apagado ya pasó'; end if;
  update public.live_meetings set active = false, ended_at = now()
   where channel = v_channel and zone_id is not distinct from v_zone and active;
  insert into public.live_meetings (channel, zone_id, audience, title, message, meet_url, ends_at, created_by)
  values (v_channel, v_zone, p_audience, v_title, v_msg, trim(p_meet_url), p_ends_at, auth.uid())
  returning id into v_id;
  if p_send_push then
    v_push := public.admin_send_push_v1(p_channel, 'push_only', left('En directo: ' || v_title, 90),
      coalesce(nullif(v_msg, ''), 'Estamos en directo. Entra a la reunión desde la app.'), p_audience, v_zone, null, null);
  end if;
  perform public.admin_log_action('live_meeting_start', 'live_meetings', v_id::text,
    jsonb_build_object('environment', v_channel, 'zone_id', v_zone, 'audience', p_audience, 'push', p_send_push));
  return jsonb_build_object('id', v_id, 'push', v_push);
end $$;
revoke all on function public.admin_live_meeting_save_v1(text, uuid, text, text, text, text, timestamptz, boolean) from public, anon;
grant execute on function public.admin_live_meeting_save_v1(text, uuid, text, text, text, text, timestamptz, boolean) to authenticated;

create or replace function public.admin_live_meeting_end_v1(p_channel text, p_zone_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_zone uuid; n int;
begin
  v_zone := public.admin_comm_scope(p_channel, p_zone_id, true);
  update public.live_meetings set active = false, ended_at = now()
   where channel = v_channel and zone_id is not distinct from v_zone and active;
  get diagnostics n = row_count;
  if n > 0 then
    perform public.admin_log_action('live_meeting_end', 'live_meetings', v_channel, jsonb_build_object('environment', v_channel, 'zone_id', v_zone));
  end if;
  return jsonb_build_object('ended', n);
end $$;
revoke all on function public.admin_live_meeting_end_v1(text, uuid) from public, anon;
grant execute on function public.admin_live_meeting_end_v1(text, uuid) to authenticated;

-- Usuario: reunión activa que le corresponde (la de su zona o la general).
create or replace function public.my_live_meeting_v1(p_channel text default 'production')
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_channel text := public.normalize_runtime_channel(p_channel); m public.live_meetings%rowtype;
begin
  if v_uid is null then return null; end if;
  perform public.live_meetings_expire();
  select * into m from public.live_meetings x
   where x.channel = v_channel and x.active and public.live_meeting_matches_user(x, v_uid)
   order by (x.zone_id is not null) desc, x.started_at desc limit 1;
  if m.id is null then return null; end if;
  return jsonb_build_object('id', m.id, 'title', m.title, 'message', m.message, 'meet_url', m.meet_url,
                            'started_at', m.started_at, 'ends_at', m.ends_at);
end $$;
revoke all on function public.my_live_meeting_v1(text) from public, anon;
grant execute on function public.my_live_meeting_v1(text) to authenticated;

create or replace function public.live_meeting_join_v1(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); m public.live_meetings%rowtype;
begin
  if v_uid is null then raise exception 'Sesión requerida'; end if;
  select * into m from public.live_meetings where id = p_id and active;
  if m.id is null or not public.live_meeting_matches_user(m, v_uid) then return; end if;
  insert into public.live_meeting_joins (meeting_id, user_id) values (m.id, v_uid) on conflict do nothing;
end $$;
revoke all on function public.live_meeting_join_v1(uuid) from public, anon;
grant execute on function public.live_meeting_join_v1(uuid) to authenticated;
