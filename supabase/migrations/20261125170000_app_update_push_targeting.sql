-- Aviso de actualización dirigido: la app informa qué versión tiene instalada y la notificación
-- «Nueva actualización» solo se envía a quienes necesitan actualizar. Al tocarla, la app abre Google Play
-- si la versión instalada es anterior; si ya está actualizada, solo abre la app.
alter table public.native_push_tokens add column if not exists app_version text;
alter table public.native_push_tokens add column if not exists app_build integer;
alter table public.native_push_tokens add column if not exists app_reported_at timestamptz;

-- Registro del token con la versión instalada (las versiones antiguas siguen usando v2 y quedan «sin versión»).
create or replace function public.register_native_push_token_v3(
  p_token text, p_platform text default 'android', p_device_label text default null,
  p_channel text default 'production', p_app_version text default null, p_app_build integer default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid;
begin
  v_id := public.register_native_push_token_v2(p_token, p_platform, p_device_label, p_channel);
  update public.native_push_tokens
     set app_version = nullif(left(trim(coalesce(p_app_version, '')), 40), ''),
         app_build = case when p_app_build is not null and p_app_build between 1 and 100000 then p_app_build end,
         app_reported_at = now()
   where id = v_id;
  return v_id;
end $$;
revoke all on function public.register_native_push_token_v3(text, text, text, text, text, integer) from public, anon;
grant execute on function public.register_native_push_token_v3(text, text, text, text, text, integer) to authenticated;

-- Usuarios Android alcanzables por push, con su mejor versión conocida (máxima entre sus dispositivos activos).
create or replace function public.app_update_candidates(p_channel text, p_audience text, p_zone_id uuid, p_build integer)
returns table (user_id uuid, best_build integer, status text) language sql stable security definer set search_path to 'public' as $$
  with dev as (
    select t.user_id, max(t.app_build) as best_build
      from public.native_push_tokens t
     where t.active and t.platform = 'android' and t.channel = p_channel
     group by t.user_id
  )
  select d.user_id, d.best_build,
         case when d.best_build is null then 'unknown'
              when d.best_build >= p_build then 'updated' else 'outdated' end
    from dev d
    join public.users u on u.id = d.user_id and u.account_status = 'active'
    left join public.driver_profiles dp on dp.id = u.id
   where public.comm_user_in_channel(u.id, p_channel)
     and (p_audience = 'all'
          or (p_audience = 'drivers' and u.active_mode = 'driver' and dp.id is not null and dp.approval_status = 'approved')
          or (p_audience = 'passengers' and u.active_mode = 'passenger'))
     and (p_zone_id is null or (case when p_audience = 'drivers' then dp.zone_id
                                     when p_audience = 'passengers' then u.last_zone_id
                                     when dp.id is not null and dp.approval_status = 'approved' then dp.zone_id
                                     else u.last_zone_id end) = p_zone_id);
$$;
revoke all on function public.app_update_candidates(text, text, uuid, integer) from public, anon, authenticated;

create or replace function public.admin_app_update_audience_v1(p_channel text, p_build_number integer, p_audience text, p_zone_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); v_zone uuid;
begin
  v_zone := public.admin_comm_scope(p_channel, p_zone_id, true);
  if p_audience not in ('all', 'drivers', 'passengers') then raise exception 'Audiencia inválida'; end if;
  return (
    select jsonb_build_object(
      'total', count(*)::int,
      'updated', count(*) filter (where status = 'updated')::int,
      'outdated', count(*) filter (where status = 'outdated')::int,
      'unknown', count(*) filter (where status = 'unknown')::int,
      'will_receive', count(*) filter (where status in ('outdated', 'unknown'))::int)
      from public.app_update_candidates(v_channel, p_audience, v_zone, p_build_number));
end $$;
revoke all on function public.admin_app_update_audience_v1(text, integer, text, uuid) from public, anon;
grant execute on function public.admin_app_update_audience_v1(text, integer, text, uuid) to authenticated;

create or replace function public.admin_send_app_update_push_v1(
  p_channel text, p_build_number integer, p_audience text default 'all', p_zone_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_channel text := public.normalize_runtime_channel(p_channel); v_zone uuid; rel public.app_releases%rowtype;
  v_campaign uuid; v_count int := 0; v_title text; v_body text; v_url text; v_meta jsonb;
begin
  v_zone := public.admin_comm_scope(p_channel, p_zone_id, true);
  if p_audience not in ('all', 'drivers', 'passengers') then raise exception 'Audiencia inválida'; end if;
  select * into rel from public.app_releases
   where platform = 'android' and status = 'published' and build_number = p_build_number
   order by published_at desc limit 1;
  if rel.id is null then raise exception 'Esa versión no está publicada para los usuarios'; end if;
  v_url := coalesce(nullif(rel.play_store_url, ''), 'https://play.google.com/store/apps/details?id=com.express.usuario1');
  if v_url not like 'https://play.google.com/store/apps/details?id=com.express.usuario1%' then
    v_url := 'https://play.google.com/store/apps/details?id=com.express.usuario1';
  end if;
  v_title := 'Nueva actualización de Express';
  v_body := 'Descarga la versión ' || rel.version_name || ' (build ' || rel.build_number || ') para seguir usando Express sin problemas.';
  v_meta := jsonb_build_object('campaign', true, 'environment', v_channel, 'channel', v_channel,
    'deep_link', 'app_update/' || rel.build_number, 'build_number', rel.build_number,
    'version_name', rel.version_name, 'play_store_url', v_url);

  insert into public.notification_campaigns (title, body, audience, zone_id, created_by, channel)
  values (v_title, v_body, p_audience, v_zone, auth.uid(), v_channel) returning id into v_campaign;

  with targets as (
    select c.user_id from public.app_update_candidates(v_channel, p_audience, v_zone, rel.build_number) c
     where c.status in ('outdated', 'unknown')
  ), ins as (
    insert into public.notifications (user_id, title, body, type, metadata, campaign_id, channel)
    select t.user_id, v_title, v_body, 'app_update', v_meta || jsonb_build_object('campaign_id', v_campaign), v_campaign, v_channel
      from targets t returning id)
  select count(*) into v_count from ins;

  update public.notification_campaigns set recipients_targeted = v_count, push_enabled_recipients = v_count where id = v_campaign;
  perform public.admin_log_action('send_app_update_push', 'notification_campaigns', v_campaign::text,
    jsonb_build_object('environment', v_channel, 'build', rel.build_number, 'audience', p_audience, 'zone_id', v_zone, 'recipients', v_count));
  return jsonb_build_object('campaign_id', v_campaign, 'recipients', v_count, 'build_number', rel.build_number);
end $$;
revoke all on function public.admin_send_app_update_push_v1(text, integer, text, uuid) from public, anon;
grant execute on function public.admin_send_app_update_push_v1(text, integer, text, uuid) to authenticated;
