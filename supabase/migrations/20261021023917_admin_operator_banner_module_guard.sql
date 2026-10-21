begin;

-- Landing banners are a marketplace capability. An operator must have that
-- module assigned, the module must be enabled for operators, and the requested
-- zone must resolve to the operator's server-assigned zone.
create or replace function public.admin_landing_banner_save_v1(
  p_id uuid,
  p_zone_id uuid,
  p_channel text,
  p_title text,
  p_subtitle text,
  p_cta_label text,
  p_image_url text,
  p_target_module text,
  p_target_url text,
  p_style_key text,
  p_active boolean,
  p_sort_order integer,
  p_starts_at timestamp with time zone default null,
  p_ends_at timestamp with time zone default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_ctx jsonb;
  v_id uuid;
  v_country text;
  v_zone_id uuid;
begin
  v_ctx := public.admin_access_context();
  if v_ctx->>'allowed' is distinct from 'true'
     or v_ctx->>'read_only' = 'true'
     or p_channel is null
     or p_channel not in ('preview', 'production')
     or not public.admin_environment_allowed(p_channel)
     or p_zone_id is null then
    raise exception 'No autorizado para administrar publicidad';
  end if;

  perform public.admin_operator_assert_module('marketplace');
  v_zone_id := public.admin_effective_zone_id(p_zone_id);

  if v_ctx->>'role' = 'operator'
     and not exists (
       select 1
       from public.admin_operator_module_capabilities c
       where c.module_key = 'marketplace'
         and c.runtime_ready = true
     ) then
    raise exception 'Modulo sin autorizacion para esta zona';
  end if;

  select z.country_code
    into v_country
  from public.service_zones z
  where z.id = v_zone_id;
  if not found then
    raise exception 'Zona no encontrada';
  end if;

  if v_ctx->>'zone_id' is not null
     and v_ctx->>'zone_id' <> v_zone_id::text then
    raise exception 'Zona fuera de tus permisos';
  end if;
  if v_ctx->>'country_code' is not null
     and v_ctx->>'country_code' <> v_country then
    raise exception 'País fuera de tus permisos';
  end if;
  if nullif(pg_catalog.btrim(coalesce(p_title, '')), '') is null then
    raise exception 'Escribe un título';
  end if;
  if p_id is not null and not exists (
    select 1
    from public.passenger_landing_banners b
    where b.id = p_id
      and b.zone_id = v_zone_id
      and b.channel = p_channel
  ) then
    raise exception 'El banner no pertenece a la zona y entorno';
  end if;

  insert into public.passenger_landing_banners as current_banner (
    id, zone_id, channel, title, subtitle, cta_label, image_url,
    target_module, target_url, style_key, active, sort_order,
    starts_at, ends_at, updated_at
  ) values (
    coalesce(p_id, pg_catalog.gen_random_uuid()), v_zone_id, p_channel,
    pg_catalog.btrim(p_title), coalesce(p_subtitle, ''),
    coalesce(nullif(pg_catalog.btrim(p_cta_label), ''), 'Descubrir'),
    nullif(pg_catalog.btrim(coalesce(p_image_url, '')), ''),
    nullif(pg_catalog.btrim(coalesce(p_target_module, '')), ''),
    nullif(pg_catalog.btrim(coalesce(p_target_url, '')), ''),
    coalesce(nullif(pg_catalog.btrim(p_style_key), ''), 'blue'),
    coalesce(p_active, true), coalesce(p_sort_order, 100),
    p_starts_at, p_ends_at, pg_catalog.now()
  )
  on conflict (id) do update set
    title = excluded.title,
    subtitle = excluded.subtitle,
    cta_label = excluded.cta_label,
    image_url = excluded.image_url,
    target_module = excluded.target_module,
    target_url = excluded.target_url,
    style_key = excluded.style_key,
    active = excluded.active,
    sort_order = excluded.sort_order,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    updated_at = pg_catalog.now()
  where current_banner.zone_id = excluded.zone_id
    and current_banner.channel = excluded.channel
  returning id into v_id;

  if v_id is null then
    raise exception 'El banner cambió de zona o entorno; vuelve a cargarlo';
  end if;

  if v_ctx->>'role' = 'operator' then
    insert into public.admin_audit_log (
      admin_user_id, action, entity_type, entity_id, details
    ) values (
      auth.uid(),
      case when p_id is null then 'create_landing_banner' else 'update_landing_banner' end,
      'passenger_landing_banners',
      v_id::text,
      pg_catalog.jsonb_build_object('zone_id', v_zone_id, 'channel', p_channel)
    );
  end if;

  return v_id;
end
$function$;

create or replace function public.admin_landing_banners_list_v1(
  p_zone_id uuid,
  p_channel text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_ctx jsonb;
  v_zone_country text;
  v_zone_id uuid;
  v_banners jsonb;
begin
  v_ctx := public.admin_access_context();
  if v_ctx->>'allowed' is distinct from 'true'
     or p_channel is null
     or p_channel not in ('preview', 'production')
     or not public.admin_environment_allowed(p_channel)
     or p_zone_id is null then
    raise exception 'No autorizado';
  end if;

  perform public.admin_operator_assert_module('marketplace');
  v_zone_id := public.admin_effective_zone_id(p_zone_id);

  if v_ctx->>'role' = 'operator'
     and not exists (
       select 1
       from public.admin_operator_module_capabilities c
       where c.module_key = 'marketplace'
         and c.runtime_ready = true
     ) then
    raise exception 'Modulo sin autorizacion para esta zona';
  end if;

  select z.country_code
    into v_zone_country
  from public.service_zones z
  where z.id = v_zone_id;
  if not found then
    raise exception 'Zona no encontrada';
  end if;

  if v_ctx->>'zone_id' is not null
     and v_ctx->>'zone_id' <> v_zone_id::text then
    raise exception 'Zona fuera de tus permisos';
  end if;
  if v_ctx->>'country_code' is not null
     and v_ctx->>'country_code' <> v_zone_country then
    raise exception 'País fuera de tus permisos';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.to_jsonb(b)
      order by b.sort_order, b.created_at desc
    ),
    '[]'::jsonb
  )
  into v_banners
  from public.passenger_landing_banners b
  where b.zone_id = v_zone_id
    and b.channel = p_channel;

  return v_banners;
end
$function$;

revoke all on function public.admin_landing_banner_save_v1(
  uuid, uuid, text, text, text, text, text, text, text, text, boolean,
  integer, timestamp with time zone, timestamp with time zone
) from public, anon;
grant execute on function public.admin_landing_banner_save_v1(
  uuid, uuid, text, text, text, text, text, text, text, text, boolean,
  integer, timestamp with time zone, timestamp with time zone
) to authenticated, service_role;

revoke all on function public.admin_landing_banners_list_v1(uuid, text)
  from public, anon;
grant execute on function public.admin_landing_banners_list_v1(uuid, text)
  to authenticated, service_role;

commit;
