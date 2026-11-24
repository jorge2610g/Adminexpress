-- Solicitudes de cambio de perfil de conductor (foto, nombre, teléfono). El conductor aprobado ya no
-- edita estos datos directamente: envía una solicitud y la administración la aprueba o rechaza.
create table if not exists public.driver_profile_change_requests (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.users(id) on delete cascade,
  kind text not null check (kind in ('photo', 'name', 'phone')),
  old_value text,
  new_value text,
  new_photo_path text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reject_reason text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists driver_profile_change_one_pending
  on public.driver_profile_change_requests (driver_id, kind) where status = 'pending';
create index if not exists driver_profile_change_status_idx
  on public.driver_profile_change_requests (status, created_at desc);
alter table public.driver_profile_change_requests enable row level security;
drop policy if exists driver_profile_change_read_own on public.driver_profile_change_requests;
create policy driver_profile_change_read_own on public.driver_profile_change_requests for select
  using (driver_id = (select auth.uid()));

-- El conductor aprobado no puede cambiar nombre, teléfono ni foto directamente desde la app.
create or replace function public.guard_driver_profile_direct_edit()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  if current_user <> 'authenticated' or auth.uid() is distinct from old.id then return new; end if;
  if new.full_name is not distinct from old.full_name
     and new.avatar_url is not distinct from old.avatar_url
     and (new.phone is not distinct from old.phone or coalesce(old.phone, '') = '') then
    return new;
  end if;
  if public.is_admin() then return new; end if;
  if exists (select 1 from public.driver_profiles dp where dp.id = old.id and dp.approval_status = 'approved') then
    raise exception 'Los cambios de nombre, teléfono y foto de un conductor necesitan aprobación. Envía una solicitud.';
  end if;
  return new;
end $$;
drop trigger if exists guard_driver_profile_direct_edit on public.users;
create trigger guard_driver_profile_direct_edit before update of full_name, phone, avatar_url on public.users
  for each row execute function public.guard_driver_profile_direct_edit();

create or replace function public.driver_request_profile_change_v1(p_kind text, p_value text default null, p_photo_path text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_old text; v_new text := trim(coalesce(p_value, '')); v_id uuid; u public.users%rowtype;
begin
  if v_uid is null then raise exception 'Sesión requerida'; end if;
  if not exists (select 1 from public.driver_profiles where id = v_uid) then raise exception 'Solo conductores'; end if;
  select * into u from public.users where id = v_uid;
  if p_kind = 'name' then
    if char_length(v_new) < 2 or char_length(v_new) > 80 then raise exception 'Escribe un nombre válido'; end if;
    v_old := u.full_name;
    if v_new = coalesce(v_old, '') then raise exception 'Ese ya es tu nombre actual'; end if;
  elsif p_kind = 'phone' then
    v_new := regexp_replace(v_new, '\s', '', 'g');
    if v_new !~ '^\+?[0-9]{7,15}$' then raise exception 'Escribe un teléfono válido'; end if;
    v_old := u.phone;
    if v_new = coalesce(v_old, '') then raise exception 'Ese ya es tu teléfono actual'; end if;
  elsif p_kind = 'photo' then
    if p_photo_path is null or p_photo_path not like v_uid::text || '/profile-change/%' then raise exception 'Foto inválida'; end if;
    v_new := null;
  else
    raise exception 'Tipo de solicitud inválido';
  end if;
  update public.driver_profile_change_requests set status = 'cancelled'
   where driver_id = v_uid and kind = p_kind and status = 'pending';
  insert into public.driver_profile_change_requests (driver_id, kind, old_value, new_value, new_photo_path)
  values (v_uid, p_kind, v_old, nullif(v_new, ''), case when p_kind = 'photo' then p_photo_path end)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'status', 'pending');
end $$;
revoke all on function public.driver_request_profile_change_v1(text, text, text) from public, anon;
grant execute on function public.driver_request_profile_change_v1(text, text, text) to authenticated;

create or replace function public.my_driver_profile_change_requests_v1()
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'kind', r.kind, 'new_value', r.new_value,
           'status', r.status, 'reject_reason', r.reject_reason, 'created_at', r.created_at, 'reviewed_at', r.reviewed_at)
           order by r.created_at desc), '[]'::jsonb)
    from (select * from public.driver_profile_change_requests
           where driver_id = auth.uid() and status <> 'cancelled'
           order by created_at desc limit 20) r;
$$;
revoke all on function public.my_driver_profile_change_requests_v1() from public, anon;
grant execute on function public.my_driver_profile_change_requests_v1() to authenticated;

-- Panel: permisos y zona.
create or replace function public.admin_driver_requests_scope(p_channel text, p_zone_id uuid)
returns uuid language plpgsql stable security definer set search_path to 'public' as $$
begin
  p_zone_id := public.admin_scope_zone(p_zone_id);
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  if public.admin_zone_role_now() = 'operator' then
    perform public.admin_operator_assert_module('drivers');
    p_zone_id := public.admin_effective_zone_id(p_zone_id);
  elsif not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  return p_zone_id;
end $$;
revoke all on function public.admin_driver_requests_scope(text, uuid) from public, anon, authenticated;

create or replace function public.admin_driver_requests_v1(p_channel text, p_zone_id uuid, p_status text default 'pending')
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_hist boolean := lower(coalesce(p_status, 'pending')) = 'history';
begin
  p_zone_id := public.admin_driver_requests_scope(p_channel, p_zone_id);
  if p_zone_id is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(x.j order by x.at desc) from (
      select r.created_at as at, jsonb_build_object(
        'id', r.id::text, 'request_kind', r.kind, 'driver_id', r.driver_id, 'driver_name', u.full_name, 'driver_phone', u.phone,
        'old_value', r.old_value, 'new_value', r.new_value, 'new_photo_path', r.new_photo_path,
        'status', r.status, 'reject_reason', r.reject_reason, 'created_at', r.created_at, 'reviewed_at', r.reviewed_at,
        'reviewed_by_name', (select ru.full_name from public.users ru where ru.id = r.reviewed_by)) as j
      from public.driver_profile_change_requests r
      join public.users u on u.id = r.driver_id
      join public.driver_profiles dp on dp.id = r.driver_id
      where dp.zone_id = p_zone_id and public.comm_user_in_channel(r.driver_id, v_channel)
        and ((not v_hist and r.status = 'pending') or (v_hist and r.status in ('approved', 'rejected')))
      union all
      select coalesce(w.requested_at, w.updated_at), jsonb_build_object(
        'id', w.driver_id::text || ':' || w.service_key, 'request_kind', 'service', 'driver_id', w.driver_id,
        'driver_name', u.full_name, 'driver_phone', u.phone, 'service_key', w.service_key,
        'status', w.status, 'created_at', coalesce(w.requested_at, w.updated_at), 'reviewed_at', w.reviewed_at,
        'reviewed_by_name', (select ru.full_name from public.users ru where ru.id = w.reviewed_by))
      from public.driver_work_permissions w
      join public.users u on u.id = w.driver_id
      join public.driver_profiles dp on dp.id = w.driver_id
      where dp.zone_id = p_zone_id and w.channel = v_channel
        and ((not v_hist and w.status = 'pending') or (v_hist and w.status in ('approved', 'rejected')))
    ) x), '[]'::jsonb);
end $$;
revoke all on function public.admin_driver_requests_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_driver_requests_v1(text, uuid, text) to authenticated;

create or replace function public.admin_driver_profile_change_review_v1(p_channel text, p_id uuid, p_approve boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare r public.driver_profile_change_requests%rowtype; v_channel text := public.normalize_runtime_channel(p_channel);
  v_reason text := nullif(left(trim(coalesce(p_reason, '')), 300), ''); v_label text;
begin
  select * into r from public.driver_profile_change_requests where id = p_id for update;
  if r.id is null then raise exception 'Solicitud no encontrada'; end if;
  if r.status <> 'pending' then raise exception 'La solicitud ya fue resuelta'; end if;
  perform public.admin_assert_target_environment(r.driver_id, v_channel);
  if not public.admin_can('drivers.work_permissions', public.admin_zone_of_user(r.driver_id)) then
    raise exception 'No autorizado';
  end if;
  if not p_approve and v_reason is null then raise exception 'Escribe el motivo del rechazo'; end if;
  if p_approve then
    if r.kind = 'name' then update public.users set full_name = r.new_value, updated_at = now() where id = r.driver_id;
    elsif r.kind = 'phone' then update public.users set phone = r.new_value, updated_at = now() where id = r.driver_id;
    else update public.driver_profiles set profile_photo_path = r.new_photo_path where id = r.driver_id;
    end if;
  end if;
  update public.driver_profile_change_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         reject_reason = case when p_approve then null else v_reason end,
         reviewed_by = auth.uid(), reviewed_at = now()
   where id = r.id;
  v_label := case r.kind when 'name' then 'tu nombre' when 'phone' then 'tu teléfono' else 'tu foto de perfil' end;
  insert into public.notifications (user_id, title, body, type, metadata, channel)
  values (r.driver_id,
          case when p_approve then 'Cambio aprobado' else 'Cambio rechazado' end,
          case when p_approve then 'Aprobamos el cambio de ' || v_label || '.'
               else 'No aprobamos el cambio de ' || v_label || '. Motivo: ' || v_reason end,
          'driver_profile_review',
          jsonb_build_object('environment', v_channel, 'channel', v_channel, 'request_id', r.id), v_channel);
  perform public.admin_log_action('driver_profile_change_' || case when p_approve then 'approve' else 'reject' end,
    'driver_profile_change_requests', r.id::text, jsonb_build_object('environment', v_channel, 'driver_id', r.driver_id, 'kind', r.kind));
  return jsonb_build_object('ok', true, 'status', case when p_approve then 'approved' else 'rejected' end);
end $$;
revoke all on function public.admin_driver_profile_change_review_v1(text, uuid, boolean, text) from public, anon;
grant execute on function public.admin_driver_profile_change_review_v1(text, uuid, boolean, text) to authenticated;
