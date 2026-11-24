-- Notificaciones / Avisos reorganizados:
--  1) Soporte: conversaciones (tickets) con estado abierta / cerrada, cierre con nota y reapertura.
--  2) Avisos: mensajes editoriales (evento, importante, novedad, aviso) que el usuario puede abrir
--     cuando quiera desde su menú. Una fila por aviso (no una por destinatario) y un registro de lectura.
--  3) Push: «solo notificación push» (tipo push_broadcast) o «push con aviso» (tipo announcement, abre el aviso).

-- ───────────────────────────── helpers ─────────────────────────────
-- ¿El usuario pertenece al entorno? Preview = grupo QA activo; Producción = el resto.
create or replace function public.comm_user_in_channel(p_user uuid, p_channel text)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select (p_channel = 'preview' and exists(
            select 1 from public.audit_test_group_members q where q.enabled = true and q.user_id = p_user))
      or (p_channel = 'production' and not exists(
            select 1 from public.audit_test_group_members q where q.enabled = true and q.user_id = p_user));
$$;
revoke all on function public.comm_user_in_channel(uuid, text) from public, anon, authenticated;

-- Permisos y zona para las pantallas de comunicaciones. p_write exige poder enviar notificaciones.
create or replace function public.admin_comm_scope(p_channel text, p_zone_id uuid, p_write boolean)
returns uuid language plpgsql stable security definer set search_path to 'public' as $$
begin
  p_zone_id := public.admin_scope_zone(p_zone_id);
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  if p_write then
    perform public.admin_require_permission('notifications.send', p_zone_id);
    if public.admin_zone_role_now() = 'zone_monitor' then
      raise exception 'El monitor no puede enviar notificaciones';
    end if;
  end if;
  if public.admin_zone_role_now() = 'operator' then
    perform public.admin_operator_assert_module('notifications');
    p_zone_id := public.admin_effective_zone_id(p_zone_id);
  elsif not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  return p_zone_id;
end $$;
revoke all on function public.admin_comm_scope(text, uuid, boolean) from public, anon, authenticated;

-- ───────────────────────────── 1) SOPORTE ─────────────────────────────
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'closed')),
  opened_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  closed_at timestamptz,
  closed_by uuid references public.users(id) on delete set null,
  close_note text
);
create unique index if not exists support_tickets_one_open_per_user
  on public.support_tickets (user_id) where status = 'open';
create index if not exists support_tickets_user_idx on public.support_tickets (user_id, opened_at desc);
alter table public.support_tickets enable row level security;
drop policy if exists support_tickets_read_own on public.support_tickets;
create policy support_tickets_read_own on public.support_tickets for select
  using (user_id = (select auth.uid()));

alter table public.support_messages add column if not exists ticket_id uuid references public.support_tickets(id) on delete cascade;
create index if not exists support_messages_ticket_idx on public.support_messages (ticket_id, created_at);

-- Lo que ya existía: una conversación abierta por usuario con mensajes.
insert into public.support_tickets (user_id, status, opened_at, last_message_at)
select m.user_id, 'open', min(m.created_at), max(m.created_at)
  from public.support_messages m
 where m.ticket_id is null
   and not exists (select 1 from public.support_tickets t where t.user_id = m.user_id)
 group by m.user_id;
update public.support_messages m set ticket_id = t.id
  from public.support_tickets t where t.user_id = m.user_id and m.ticket_id is null;

-- Cada mensaje nuevo va a la conversación abierta del usuario; si no hay, se abre una nueva.
create or replace function public.support_message_assign_ticket()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.ticket_id is null then
    select t.id into new.ticket_id from public.support_tickets t
     where t.user_id = new.user_id and t.status = 'open';
    if new.ticket_id is null then
      insert into public.support_tickets (user_id) values (new.user_id) returning id into new.ticket_id;
    end if;
  end if;
  update public.support_tickets set last_message_at = now() where id = new.ticket_id;
  return new;
end $$;
revoke all on function public.support_message_assign_ticket() from public, anon, authenticated;
drop trigger if exists trg_a_support_message_assign_ticket on public.support_messages;
create trigger trg_a_support_message_assign_ticket before insert on public.support_messages
  for each row execute function public.support_message_assign_ticket();

create or replace function public.admin_support_tickets_v1(p_channel text, p_zone_id uuid, p_status text default 'open')
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_status text := lower(coalesce(nullif(trim(p_status), ''), 'open'));
begin
  p_zone_id := public.admin_comm_scope(p_channel, p_zone_id, false);
  if v_status not in ('open', 'closed') then raise exception 'Estado inválido'; end if;
  if p_zone_id is null then
    return jsonb_build_object('open_count', 0, 'closed_count', 0, 'tickets', '[]'::jsonb);
  end if;
  return (
    with base as (
      select t.*, u.full_name, u.phone, coalesce(dp.zone_id, u.last_zone_id) as zone_id,
             (dp.id is not null and dp.approval_status = 'approved') as is_driver
        from public.support_tickets t
        join public.users u on u.id = t.user_id
        left join public.driver_profiles dp on dp.id = t.user_id
       where coalesce(dp.zone_id, u.last_zone_id) = p_zone_id
         and public.comm_user_in_channel(t.user_id, v_channel)
    )
    select jsonb_build_object(
      'open_count', (select count(*) from base where status = 'open'),
      'closed_count', (select count(*) from base where status = 'closed'),
      'tickets', coalesce((
        select jsonb_agg(jsonb_build_object(
          'ticket_id', b.id, 'user_id', b.user_id, 'full_name', b.full_name, 'phone', b.phone,
          'role', case when b.is_driver then 'driver' else 'passenger' end,
          'status', b.status, 'opened_at', b.opened_at, 'closed_at', b.closed_at,
          'closed_by_name', (select cu.full_name from public.users cu where cu.id = b.closed_by),
          'close_note', b.close_note,
          'last_message', lm.body, 'last_sender_role', lm.sender_role,
          'last_message_at', coalesce(lm.created_at, b.last_message_at),
          'unread_count', (select count(*) from public.support_messages sm
                            where sm.ticket_id = b.id and sm.sender_role = 'user' and sm.read_by_admin = false)
        ) order by coalesce(lm.created_at, b.last_message_at) desc)
        from base b
        left join lateral (select m.body, m.sender_role, m.created_at from public.support_messages m
                            where m.ticket_id = b.id order by m.created_at desc limit 1) lm on true
        where b.status = v_status), '[]'::jsonb)
    ) from (select 1) one
  );
end $$;
revoke all on function public.admin_support_tickets_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_support_tickets_v1(text, uuid, text) to authenticated;

create or replace function public.admin_support_ticket_messages_v1(p_channel text, p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare t public.support_tickets%rowtype; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  perform public.admin_comm_scope(p_channel, null, false);
  select * into t from public.support_tickets where id = p_ticket_id;
  if t.id is null then raise exception 'Conversación no encontrada'; end if;
  if not public.comm_user_in_channel(t.user_id, v_channel) then raise exception 'Usuario fuera del entorno seleccionado'; end if;
  if public.admin_zone_role_now() = 'operator' and public.admin_zone_of_user(t.user_id) is distinct from public.admin_effective_zone_id(null) then
    raise exception 'Conversación fuera de la zona del operador';
  end if;
  update public.support_messages set read_by_admin = true
   where ticket_id = t.id and sender_role = 'user' and read_by_admin = false;
  return jsonb_build_object(
    'ticket', jsonb_build_object('ticket_id', t.id, 'user_id', t.user_id, 'status', t.status, 'opened_at', t.opened_at,
      'closed_at', t.closed_at, 'close_note', t.close_note,
      'closed_by_name', (select cu.full_name from public.users cu where cu.id = t.closed_by)),
    'messages', coalesce((select jsonb_agg(to_jsonb(sm) order by sm.created_at)
                            from public.support_messages sm where sm.ticket_id = t.id), '[]'::jsonb));
end $$;
revoke all on function public.admin_support_ticket_messages_v1(text, uuid) from public, anon;
grant execute on function public.admin_support_ticket_messages_v1(text, uuid) to authenticated;

create or replace function public.admin_support_ticket_reply_v1(p_channel text, p_ticket_id uuid, p_body text)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare t public.support_tickets%rowtype; v_body text := trim(coalesce(p_body, '')); v_id uuid; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  perform public.admin_comm_scope(p_channel, null, false);
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then raise exception 'Mensaje inválido'; end if;
  select * into t from public.support_tickets where id = p_ticket_id for update;
  if t.id is null then raise exception 'Conversación no encontrada'; end if;
  if t.status <> 'open' then raise exception 'La conversación está cerrada. Reábrela para responder.'; end if;
  if not public.comm_user_in_channel(t.user_id, v_channel) then raise exception 'Usuario fuera del entorno seleccionado'; end if;
  if public.admin_zone_role_now() = 'operator' and public.admin_zone_of_user(t.user_id) is distinct from public.admin_effective_zone_id(null) then
    raise exception 'Conversación fuera de la zona del operador';
  end if;
  insert into public.support_messages (user_id, sender_id, sender_role, body, read_by_user, read_by_admin, ticket_id)
  values (t.user_id, auth.uid(), 'admin', v_body, false, true, t.id) returning id into v_id;
  insert into public.notifications (user_id, title, body, type, metadata, channel)
  values (t.user_id, 'Soporte Express respondió', left(v_body, 140), 'support_reply',
          jsonb_build_object('environment', v_channel), v_channel);
  perform public.admin_log_action('support_reply', 'support_messages', v_id::text,
    jsonb_build_object('environment', v_channel, 'user_id', t.user_id, 'ticket_id', t.id));
  return v_id;
end $$;
revoke all on function public.admin_support_ticket_reply_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_support_ticket_reply_v1(text, uuid, text) to authenticated;

create or replace function public.admin_support_ticket_close_v1(p_channel text, p_ticket_id uuid, p_note text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare t public.support_tickets%rowtype; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  perform public.admin_comm_scope(p_channel, null, false);
  select * into t from public.support_tickets where id = p_ticket_id for update;
  if t.id is null then raise exception 'Conversación no encontrada'; end if;
  if not public.comm_user_in_channel(t.user_id, v_channel) then raise exception 'Usuario fuera del entorno seleccionado'; end if;
  if public.admin_zone_role_now() = 'operator' and public.admin_zone_of_user(t.user_id) is distinct from public.admin_effective_zone_id(null) then
    raise exception 'Conversación fuera de la zona del operador';
  end if;
  if t.status = 'closed' then return jsonb_build_object('ok', true, 'already_closed', true); end if;
  update public.support_tickets set status = 'closed', closed_at = now(), closed_by = auth.uid(),
         close_note = nullif(left(trim(coalesce(p_note, '')), 500), '') where id = t.id;
  update public.support_messages set read_by_admin = true where ticket_id = t.id and read_by_admin = false;
  perform public.admin_log_action('support_close', 'support_tickets', t.id::text,
    jsonb_build_object('environment', v_channel, 'user_id', t.user_id));
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.admin_support_ticket_close_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_support_ticket_close_v1(text, uuid, text) to authenticated;

create or replace function public.admin_support_ticket_reopen_v1(p_channel text, p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare t public.support_tickets%rowtype; v_channel text := public.normalize_runtime_channel(p_channel);
begin
  perform public.admin_comm_scope(p_channel, null, false);
  select * into t from public.support_tickets where id = p_ticket_id for update;
  if t.id is null then raise exception 'Conversación no encontrada'; end if;
  if not public.comm_user_in_channel(t.user_id, v_channel) then raise exception 'Usuario fuera del entorno seleccionado'; end if;
  if public.admin_zone_role_now() = 'operator' and public.admin_zone_of_user(t.user_id) is distinct from public.admin_effective_zone_id(null) then
    raise exception 'Conversación fuera de la zona del operador';
  end if;
  if t.status = 'open' then return jsonb_build_object('ok', true, 'already_open', true); end if;
  if exists (select 1 from public.support_tickets o where o.user_id = t.user_id and o.status = 'open') then
    raise exception 'El usuario ya tiene otra conversación abierta.';
  end if;
  update public.support_tickets set status = 'open', closed_at = null, closed_by = null, close_note = null where id = t.id;
  perform public.admin_log_action('support_reopen', 'support_tickets', t.id::text,
    jsonb_build_object('environment', v_channel, 'user_id', t.user_id));
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.admin_support_ticket_reopen_v1(text, uuid) from public, anon;
grant execute on function public.admin_support_ticket_reopen_v1(text, uuid) to authenticated;

-- ───────────────────────────── 2) AVISOS ─────────────────────────────
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('preview', 'production')),
  category text not null default 'aviso' check (category in ('aviso', 'evento', 'importante', 'novedad')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 8000),
  image_url text,
  audience text not null check (audience in ('drivers', 'passengers', 'all')),
  zone_id uuid references public.service_zones(id),
  partner_id uuid,
  status text not null default 'published' check (status in ('draft', 'published', 'archived')),
  publish_at timestamptz not null default now(),
  expires_at timestamptz,
  push_campaign_id uuid references public.notification_campaigns(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists announcements_channel_idx on public.announcements (channel, status, publish_at desc);
create table if not exists public.announcement_reads (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, user_id)
);
alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;
drop policy if exists announcement_reads_read_own on public.announcement_reads;
create policy announcement_reads_read_own on public.announcement_reads for select using (user_id = (select auth.uid()));

-- ¿Le corresponde este aviso a este usuario? (audiencia, zona y organización; mismas reglas que el envío push)
create or replace function public.announcement_matches_user(a public.announcements, p_user uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.users u
    left join public.driver_profiles dp on dp.id = u.id
    where u.id = p_user and u.account_status = 'active'
      and (a.audience = 'all'
           or (a.audience = 'drivers' and dp.id is not null and dp.approval_status = 'approved')
           or (a.audience = 'passengers' and (u.active_mode = 'passenger' or dp.id is null or dp.approval_status <> 'approved')))
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

-- Lista del usuario: avisos publicados que le corresponden + alertas personales de su cuenta.
create or replace function public.my_announcements_v1(p_channel text default 'production', p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_channel text := public.normalize_runtime_channel(p_channel);
begin
  if v_uid is null then raise exception 'Sesión requerida'; end if;
  if not public.comm_user_in_channel(v_uid, v_channel) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(x.j order by x.at desc) from (
      select a.publish_at as at, jsonb_build_object(
        'id', a.id, 'kind', 'announcement', 'category', a.category, 'title', a.title, 'body', a.body,
        'image_url', a.image_url, 'publish_at', a.publish_at, 'expires_at', a.expires_at,
        'is_read', exists (select 1 from public.announcement_reads r where r.announcement_id = a.id and r.user_id = v_uid),
        'with_push', a.push_campaign_id is not null) as j
      from public.announcements a
      where a.channel = v_channel and a.status = 'published' and a.publish_at <= now()
        and (a.expires_at is null or a.expires_at > now())
        and public.announcement_matches_user(a, v_uid)
      union all
      select n.created_at, jsonb_build_object(
        'id', n.id, 'kind', 'account', 'category', 'importante', 'title', n.title, 'body', n.body,
        'image_url', null, 'publish_at', n.created_at, 'expires_at', null,
        'is_read', n.is_read, 'with_push', true)
      from public.notifications n
      where n.user_id = v_uid and n.type = 'admin_announcement' and n.campaign_id is null and n.channel = v_channel
      order by 1 desc
      limit greatest(1, least(coalesce(p_limit, 100), 300))
    ) x), '[]'::jsonb);
end $$;
revoke all on function public.my_announcements_v1(text, integer) from public, anon;
grant execute on function public.my_announcements_v1(text, integer) to authenticated;

create or replace function public.my_announcements_unread_v1(p_channel text default 'production')
returns integer language plpgsql stable security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_channel text := public.normalize_runtime_channel(p_channel); n int;
begin
  if v_uid is null then return 0; end if;
  if not public.comm_user_in_channel(v_uid, v_channel) then return 0; end if;
  select (select count(*) from public.announcements a
           where a.channel = v_channel and a.status = 'published' and a.publish_at <= now()
             and (a.expires_at is null or a.expires_at > now())
             and public.announcement_matches_user(a, v_uid)
             and not exists (select 1 from public.announcement_reads r where r.announcement_id = a.id and r.user_id = v_uid))
       + (select count(*) from public.notifications nn where nn.user_id = v_uid and nn.type = 'admin_announcement'
             and nn.campaign_id is null and nn.channel = v_channel and nn.is_read = false)
    into n;
  return coalesce(n, 0);
end $$;
revoke all on function public.my_announcements_unread_v1(text) from public, anon;
grant execute on function public.my_announcements_unread_v1(text) to authenticated;

create or replace function public.announcement_mark_read_v1(p_id uuid, p_channel text default 'production')
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_channel text := public.normalize_runtime_channel(p_channel); a public.announcements%rowtype;
begin
  if v_uid is null then raise exception 'Sesión requerida'; end if;
  select * into a from public.announcements where id = p_id;
  if a.id is not null then
    if a.channel = v_channel and public.announcement_matches_user(a, v_uid) then
      insert into public.announcement_reads (announcement_id, user_id) values (a.id, v_uid) on conflict do nothing;
    end if;
    return;
  end if;
  update public.notifications set is_read = true
   where id = p_id and user_id = v_uid and type = 'admin_announcement' and campaign_id is null;
end $$;
revoke all on function public.announcement_mark_read_v1(uuid, text) from public, anon;
grant execute on function public.announcement_mark_read_v1(uuid, text) to authenticated;

-- Administración de avisos.
create or replace function public.admin_announcement_save_v1(
  p_channel text, p_id uuid, p_category text, p_title text, p_body text, p_image_url text,
  p_audience text, p_zone_id uuid, p_partner_id uuid, p_publish_at timestamptz, p_expires_at timestamptz,
  p_status text default 'published')
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_id uuid := p_id;
  v_title text := trim(coalesce(p_title, '')); v_body text := trim(coalesce(p_body, ''));
begin
  p_zone_id := public.admin_comm_scope(p_channel, p_zone_id, true);
  if public.admin_zone_role_now() = 'operator' and p_partner_id is not null and not exists (
       select 1 from public.partner_organizations p where p.id = p_partner_id and p.zone_id = p_zone_id) then
    raise exception 'El socio no pertenece a tu zona';
  end if;
  if char_length(v_title) < 1 or char_length(v_title) > 120 then raise exception 'Título inválido (1 a 120 caracteres)'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 8000 then raise exception 'Mensaje inválido (1 a 8000 caracteres)'; end if;
  if p_category not in ('aviso', 'evento', 'importante', 'novedad') then raise exception 'Categoría inválida'; end if;
  if p_audience not in ('drivers', 'passengers', 'all') then raise exception 'Audiencia inválida'; end if;
  if p_status not in ('draft', 'published', 'archived') then raise exception 'Estado inválido'; end if;
  if p_expires_at is not null and p_expires_at <= coalesce(p_publish_at, now()) then
    raise exception 'La fecha de borrado debe ser posterior a la de publicación';
  end if;
  if v_id is null then
    insert into public.announcements (channel, category, title, body, image_url, audience, zone_id, partner_id,
                                      status, publish_at, expires_at, created_by)
    values (v_channel, p_category, v_title, v_body, nullif(trim(coalesce(p_image_url, '')), ''), p_audience, p_zone_id,
            p_partner_id, p_status, coalesce(p_publish_at, now()), p_expires_at, auth.uid())
    returning id into v_id;
  else
    update public.announcements set category = p_category, title = v_title, body = v_body,
           image_url = nullif(trim(coalesce(p_image_url, '')), ''), audience = p_audience, zone_id = p_zone_id,
           partner_id = p_partner_id, status = p_status, publish_at = coalesce(p_publish_at, publish_at),
           expires_at = p_expires_at, updated_at = now()
     where id = v_id and channel = v_channel
       and (public.admin_zone_role_now() <> 'operator' or zone_id = p_zone_id);
    if not found then raise exception 'Aviso no encontrado'; end if;
  end if;
  return jsonb_build_object('id', v_id);
end $$;
revoke all on function public.admin_announcement_save_v1(text, uuid, text, text, text, text, text, uuid, uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.admin_announcement_save_v1(text, uuid, text, text, text, text, text, uuid, uuid, timestamptz, timestamptz, text) to authenticated;

create or replace function public.admin_announcement_list_v1(p_channel text, p_zone_id uuid, p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_op boolean;
begin
  p_zone_id := public.admin_comm_scope(p_channel, p_zone_id, false);
  v_op := public.admin_zone_role_now() = 'operator';
  if p_zone_id is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
      select a.id, a.category, a.title, a.body, a.image_url, a.audience, a.zone_id, z.name as zone_name, a.partner_id,
             a.status, a.publish_at, a.expires_at, a.created_at, a.push_campaign_id,
             (a.push_campaign_id is not null) as with_push,
             case when a.status = 'published' and a.publish_at <= now() and (a.expires_at is null or a.expires_at > now())
                  then 'visible' when a.status = 'published' and a.publish_at > now() then 'programado'
                  when a.status = 'published' then 'vencido' else a.status end as state,
             (select count(*) from public.announcement_reads r where r.announcement_id = a.id)::int as read_count,
             (select count(*) from public.users u where public.announcement_matches_user(a, u.id))::int as audience_size,
             c.recipients_targeted as push_recipients
        from public.announcements a
        left join public.service_zones z on z.id = a.zone_id
        left join public.notification_campaigns c on c.id = a.push_campaign_id
       where a.channel = v_channel
         and ((v_op and a.zone_id = p_zone_id) or (not v_op and (a.zone_id is null or a.zone_id = p_zone_id)))
       order by a.created_at desc
       limit greatest(1, least(coalesce(p_limit, 100), 300))) x), '[]'::jsonb);
end $$;
revoke all on function public.admin_announcement_list_v1(text, uuid, integer) from public, anon;
grant execute on function public.admin_announcement_list_v1(text, uuid, integer) to authenticated;

create or replace function public.admin_announcement_set_status_v1(p_channel text, p_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_zone uuid;
begin
  v_zone := public.admin_comm_scope(p_channel, null, true);
  if p_status not in ('draft', 'published', 'archived') then raise exception 'Estado inválido'; end if;
  update public.announcements set status = p_status, updated_at = now()
   where id = p_id and channel = v_channel
     and (public.admin_zone_role_now() <> 'operator' or zone_id = v_zone);
  if not found then raise exception 'Aviso no encontrado'; end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.admin_announcement_set_status_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_announcement_set_status_v1(text, uuid, text) to authenticated;

create or replace function public.admin_announcement_delete_v1(p_channel text, p_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_zone uuid;
begin
  v_zone := public.admin_comm_scope(p_channel, null, true);
  delete from public.announcements where id = p_id and channel = v_channel
     and (public.admin_zone_role_now() <> 'operator' or zone_id = v_zone);
  if not found then raise exception 'Aviso no encontrado'; end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.admin_announcement_delete_v1(text, uuid) from public, anon;
grant execute on function public.admin_announcement_delete_v1(text, uuid) to authenticated;

-- ───────────────────────────── 3) PUSH ─────────────────────────────
-- p_mode = 'push_only'  → solo notificación push (tipo push_broadcast); no queda en la lista de Avisos.
-- p_mode = 'with_announcement' → push con aviso: usa la audiencia del aviso (p_announcement_id), el toque
--   abre ese aviso y el aviso queda disponible en el menú Avisos.
create or replace function public.admin_send_push_v1(
  p_channel text, p_mode text, p_title text, p_body text, p_audience text default 'drivers',
  p_zone_id uuid default null, p_partner_id uuid default null, p_announcement_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_campaign uuid; v_count integer := 0; v_push integer := 0;
  v_title text := trim(coalesce(p_title, '')); v_body text := trim(coalesce(p_body, ''));
  v_type text; v_meta jsonb := '{}'::jsonb; a public.announcements%rowtype;
begin
  p_zone_id := public.admin_comm_scope(p_channel, p_zone_id, true);
  if p_mode not in ('push_only', 'with_announcement') then raise exception 'Tipo de envío inválido'; end if;
  if char_length(v_title) < 1 or char_length(v_title) > 90 then raise exception 'Título inválido'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then raise exception 'Mensaje inválido'; end if;
  if p_mode = 'with_announcement' then
    select * into a from public.announcements where id = p_announcement_id and channel = v_channel for update;
    if a.id is null then raise exception 'Aviso no encontrado'; end if;
    if public.admin_zone_role_now() = 'operator' and a.zone_id is distinct from p_zone_id then
      raise exception 'El aviso no pertenece a tu zona';
    end if;
    if a.status <> 'published' then raise exception 'Publica el aviso antes de enviar la push'; end if;
    if a.push_campaign_id is not null then raise exception 'Este aviso ya tiene una push enviada'; end if;
    p_audience := a.audience; p_zone_id := a.zone_id; p_partner_id := a.partner_id;
    v_type := 'announcement';
    v_meta := jsonb_build_object('announcement_id', a.id, 'deep_link', 'avisos/' || a.id::text);
  else
    if p_audience not in ('drivers', 'passengers', 'all') then raise exception 'Audiencia inválida'; end if;
    if public.admin_zone_role_now() = 'operator' and p_partner_id is not null and not exists (
         select 1 from public.partner_organizations p where p.id = p_partner_id and p.zone_id = p_zone_id) then
      raise exception 'El socio no pertenece a tu zona';
    end if;
    v_type := 'push_broadcast';
  end if;

  insert into public.notification_campaigns (title, body, audience, zone_id, partner_id, created_by, channel)
  values (v_title, v_body, p_audience, p_zone_id, p_partner_id, auth.uid(), v_channel)
  returning id into v_campaign;

  with audience_users as (
    select u.id,
      (exists (select 1 from public.native_push_tokens n where n.user_id = u.id and n.active = true)
       or exists (select 1 from public.push_subscriptions s where s.user_id = u.id and s.active = true)) as has_push
    from public.users u
    left join public.driver_profiles dp on dp.id = u.id
    where u.account_status = 'active'
      and (p_audience = 'all'
           or (p_audience = 'drivers' and dp.id is not null and dp.approval_status = 'approved')
           or (p_audience = 'passengers' and (u.active_mode = 'passenger' or dp.id is null or dp.approval_status <> 'approved')))
      and (p_zone_id is null or (case when p_audience = 'drivers' then dp.zone_id when p_audience = 'passengers' then u.last_zone_id
            when dp.id is not null and dp.approval_status = 'approved' then dp.zone_id else u.last_zone_id end) = p_zone_id)
      and (p_partner_id is null or exists (select 1 from public.driver_partner_memberships m
            where m.driver_id = u.id and m.partner_id = p_partner_id and m.status = 'active'))
      and public.comm_user_in_channel(u.id, v_channel)
  ),
  inserted as (
    insert into public.notifications (user_id, title, body, type, metadata, campaign_id, channel)
    select au.id, v_title, v_body, v_type,
      jsonb_strip_nulls(jsonb_build_object('audience', p_audience, 'zone_id', p_zone_id, 'partner_id', p_partner_id,
        'campaign', true, 'campaign_id', v_campaign, 'environment', v_channel)) || v_meta,
      v_campaign, v_channel
    from audience_users au
    returning id
  )
  select (select count(*)::int from inserted), (select count(*)::int from audience_users where has_push)
    into v_count, v_push;

  update public.notification_campaigns set recipients_targeted = coalesce(v_count, 0),
         push_enabled_recipients = coalesce(v_push, 0) where id = v_campaign;
  if p_mode = 'with_announcement' then
    update public.announcements set push_campaign_id = v_campaign, updated_at = now() where id = a.id;
  end if;

  if public.admin_zone_role_now() = 'operator' then
    insert into public.admin_audit_log (admin_user_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'send_push', 'notification_campaigns', v_campaign::text,
      jsonb_build_object('environment', v_channel, 'mode', p_mode, 'recipients', v_count, 'push_enabled', v_push,
        'audience', p_audience, 'zone_id', p_zone_id, 'announcement_id', p_announcement_id));
  else
    perform public.admin_log_action('send_push', 'notification_campaigns', v_campaign::text,
      jsonb_build_object('environment', v_channel, 'mode', p_mode, 'recipients', v_count, 'push_enabled', v_push,
        'audience', p_audience, 'zone_id', p_zone_id, 'announcement_id', p_announcement_id));
  end if;
  return jsonb_build_object('campaign_id', v_campaign, 'channel', v_channel, 'mode', p_mode,
    'recipients', coalesce(v_count, 0), 'push_enabled', coalesce(v_push, 0), 'audience', p_audience,
    'zone_id', p_zone_id, 'partner_id', p_partner_id, 'announcement_id', p_announcement_id);
end $$;
revoke all on function public.admin_send_push_v1(text, text, text, text, text, uuid, uuid, uuid) from public, anon;
grant execute on function public.admin_send_push_v1(text, text, text, text, text, uuid, uuid, uuid) to authenticated;
