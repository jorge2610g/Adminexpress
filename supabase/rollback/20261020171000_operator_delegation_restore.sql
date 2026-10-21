-- Reversión de permisos/funciones del módulo de delegación zonal.
-- No borra datos de pagos, tarifas, operadores ni de la aplicación.
begin;
update public.admin_operator_module_capabilities
set runtime_ready=false,updated_at=now()
where module_key in ('fares','payments','subscriptions','notifications');
-- Restaurar admin_access_context
CREATE OR REPLACE FUNCTION public.admin_access_context()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_result jsonb;
  v_runtime text := public.admin_current_runtime_environment();
begin
  select jsonb_build_object(
    'allowed', v_runtime in ('preview','production'),
    'role', a.access_role,
    'read_only', a.access_role = 'zone_monitor',
    'zone_id', a.zone_id,
    'zone_key', z.zone_key,
    'zone_name', z.name,
    'city', z.city,
    'region_department', z.region_department,
    'country', z.country,
    'country_code', z.country_code,
    'allow_preview', a.allow_preview and a.access_role not in ('zone_monitor','operator'),
    'allow_production', a.allow_production,
    'runtime_environment', v_runtime,
    'can_switch_environment', false,
    'default_environment', v_runtime,
    'allowed_environments',
      case
        when v_runtime in ('preview','production') then jsonb_build_array(v_runtime)
        else '[]'::jsonb
      end,
    'allowed_modules',
      case
        when a.allowed_modules is not null then to_jsonb(a.allowed_modules)
        when a.access_role = 'super_admin' then to_jsonb(array['*']::text[])
        when a.access_role = 'zone_monitor' then to_jsonb(array[
          'dashboard','live_operations','trips','delivery','drivers',
          'users','safety_sos','delivery_orders'
        ]::text[])
        when a.access_role = 'operator' then to_jsonb(array[
          'dashboard','live_operations','trips','drivers','users','safety_sos'
        ]::text[])
        else '[]'::jsonb
      end
  )
  into v_result
  from public.admin_users a
  join public.users u on u.id = a.user_id
  left join public.service_zones z on z.id = a.zone_id
  where a.user_id = auth.uid()
    and a.active = true
    and u.account_status = 'active'
  limit 1;

  return coalesce(
    v_result,
    jsonb_build_object(
      'allowed', false,
      'allowed_modules', '[]'::jsonb,
      'can_switch_environment', false
    )
  );
end;
$function$;

-- Restaurar admin_notification_campaign_list_scoped
CREATE OR REPLACE FUNCTION public.admin_notification_campaign_list_scoped(p_channel text, p_zone_id uuid, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text := lower(coalesce(nullif(trim(p_channel),''),'production'));
begin
   p_zone_id := public.admin_scope_zone(p_zone_id);
 -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  if v_channel not in ('preview','production') then raise exception 'Entorno inválido'; end if;
  if p_zone_id is null then return '[]'::jsonb; end if;

  return (
    select coalesce(
      jsonb_agg(to_jsonb(x) order by x.created_at desc),
      '[]'::jsonb
    )
    from (
      select
        c.id,c.title,c.body,c.audience,c.zone_id,z.name as zone_name,
        c.partner_id,p.name as partner_name,c.recipients_targeted,
        c.push_enabled_recipients,c.created_at,c.channel,
        coalesce(ev.provider_accepted_users,0)::int as provider_accepted_users,
        coalesce(ev.provider_accepted_attempts,0)::int as provider_accepted_attempts,
        coalesce(ev.provider_invalid_attempts,0)::int as provider_invalid_attempts,
        coalesce(ev.opened_users,0)::int as opened_users,
        coalesce(nt.read_users,0)::int as read_users
      from public.notification_campaigns c
      left join public.service_zones z on z.id=c.zone_id
      left join public.partner_organizations p on p.id=c.partner_id
      left join lateral (
        select
          count(distinct e.notification_id) filter(where e.event='provider_accepted') as provider_accepted_users,
          count(*) filter(where e.event='provider_accepted') as provider_accepted_attempts,
          count(*) filter(where e.event='provider_invalid') as provider_invalid_attempts,
          count(distinct e.notification_id) filter(where e.event='opened') as opened_users
        from public.notification_delivery_events e
        where e.campaign_id=c.id
      ) ev on true
      left join lateral (
        select count(*) filter(where n.is_read=true) as read_users
        from public.notifications n
        where n.campaign_id=c.id
      ) nt on true
      where c.channel=v_channel
        and (c.zone_id is null or c.zone_id=p_zone_id)
        and (p_from is null or c.created_at>=p_from)
        and (p_to is null or c.created_at<p_to)
      order by c.created_at desc
      limit greatest(1,least(coalesce(p_limit,100),500))
    ) x
  );
end;
$function$;

-- Restaurar admin_operator_assert_module
CREATE OR REPLACE FUNCTION public.admin_operator_assert_module(p_module text)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_role text; v_modules text[]; v_zone uuid;
begin
  select a.access_role, a.allowed_modules, a.zone_id
    into v_role, v_modules, v_zone
  from public.admin_users a join public.users u on u.id=a.user_id
  where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if v_role is null then raise exception 'No autorizado'; end if;
  if v_role='super_admin' then return; end if;
  if v_role='zone_monitor' then return; end if;
  if v_role <> 'operator' or v_zone is null
    or not coalesce(public.admin_environment_allowed('production'),false)
    or public.admin_current_runtime_environment() <> 'production'
    or p_module not in ('dashboard','users','drivers','trips','marketplace','delivery','delivery_orders','partners')
    or not (p_module = any(coalesce(v_modules, array[]::text[]))) then
    raise exception 'Modulo no autorizado para este operador';
  end if;
end;
$function$;

-- Restaurar admin_push_audience_estimate_v2
CREATE OR REPLACE FUNCTION public.admin_push_audience_estimate_v2(p_channel text, p_audience text DEFAULT 'drivers'::text, p_zone_id uuid DEFAULT NULL::uuid, p_partner_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=lower(coalesce(nullif(trim(p_channel),''),'production'));
  v_targeted integer;
  v_push integer;
  v_native integer;
  v_web integer;
begin
   perform public.admin_block_zone_role();
 -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  if v_channel not in ('preview','production') then raise exception 'Entorno inválido'; end if;
  if p_audience not in ('drivers','passengers','all') then raise exception 'Audiencia inválida'; end if;

  with audience_users as (
    select u.id
    from public.users u
    left join public.driver_profiles dp on dp.id=u.id
    where u.account_status='active'
      and (
        p_audience='all'
        or (p_audience='drivers' and dp.id is not null and dp.approval_status='approved')
        or (p_audience='passengers' and (u.active_mode='passenger' or dp.id is null or dp.approval_status<>'approved'))
      )
      and (p_zone_id is null or coalesce(u.last_zone_id,dp.zone_id)=p_zone_id)
      and (
        p_partner_id is null or exists(
          select 1
          from public.driver_partner_memberships m
          where m.driver_id=u.id
            and m.partner_id=p_partner_id
            and m.status='active'
        )
      )
      and (
        (v_channel='preview' and exists(
          select 1
          from public.audit_test_group_members q
          where q.enabled=true and q.user_id=u.id
        ))
        or
        (v_channel='production' and not exists(
          select 1
          from public.audit_test_group_members q
          where q.enabled=true and q.user_id=u.id
        ))
      )
  )
  select
    count(*)::int,
    count(*) filter(where exists(
      select 1 from public.native_push_tokens n
      where n.user_id=a.id and n.active=true
    ))::int,
    count(*) filter(where exists(
      select 1 from public.push_subscriptions s
      where s.user_id=a.id and s.active=true
    ))::int,
    count(*) filter(where
      exists(select 1 from public.native_push_tokens n where n.user_id=a.id and n.active=true)
      or exists(select 1 from public.push_subscriptions s where s.user_id=a.id and s.active=true)
    )::int
  into v_targeted,v_native,v_web,v_push
  from audience_users a;

  return jsonb_build_object(
    'channel',v_channel,
    'recipients',coalesce(v_targeted,0),
    'push_enabled',coalesce(v_push,0),
    'native_enabled',coalesce(v_native,0),
    'web_enabled',coalesce(v_web,0)
  );
end;
$function$;

-- Restaurar admin_send_announcement_v4
CREATE OR REPLACE FUNCTION public.admin_send_announcement_v4(p_channel text, p_title text, p_body text, p_audience text DEFAULT 'drivers'::text, p_zone_id uuid DEFAULT NULL::uuid, p_partner_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=lower(coalesce(nullif(trim(p_channel),''),'production'));
  v_campaign uuid;
  v_count integer:=0;
  v_push integer:=0;
  v_title text:=trim(coalesce(p_title,''));
  v_body text:=trim(coalesce(p_body,''));
begin
   perform public.admin_block_zone_role();
 -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  if v_channel not in ('preview','production') then raise exception 'Entorno inválido'; end if;
  if char_length(v_title)<1 or char_length(v_title)>90 then raise exception 'Título inválido'; end if;
  if char_length(v_body)<1 or char_length(v_body)>1000 then raise exception 'Mensaje inválido'; end if;
  if p_audience not in ('drivers','passengers','all') then raise exception 'Audiencia inválida'; end if;

  insert into public.notification_campaigns(
    title,body,audience,zone_id,partner_id,created_by,channel
  )
  values(
    v_title,v_body,p_audience,p_zone_id,p_partner_id,auth.uid(),v_channel
  )
  returning id into v_campaign;

  with audience_users as (
    select u.id,
      (
        exists(select 1 from public.native_push_tokens n where n.user_id=u.id and n.active=true)
        or exists(select 1 from public.push_subscriptions s where s.user_id=u.id and s.active=true)
      ) as has_push
    from public.users u
    left join public.driver_profiles dp on dp.id=u.id
    where u.account_status='active'
      and (
        p_audience='all'
        or (p_audience='drivers' and dp.id is not null and dp.approval_status='approved')
        or (p_audience='passengers' and (u.active_mode='passenger' or dp.id is null or dp.approval_status<>'approved'))
      )
      and (p_zone_id is null or coalesce(u.last_zone_id,dp.zone_id)=p_zone_id)
      and (
        p_partner_id is null or exists(
          select 1
          from public.driver_partner_memberships m
          where m.driver_id=u.id and m.partner_id=p_partner_id and m.status='active'
        )
      )
      and (
        (v_channel='preview' and exists(
          select 1 from public.audit_test_group_members q
          where q.enabled=true and q.user_id=u.id
        ))
        or
        (v_channel='production' and not exists(
          select 1 from public.audit_test_group_members q
          where q.enabled=true and q.user_id=u.id
        ))
      )
  ),
  inserted as (
    insert into public.notifications(
      user_id,title,body,type,metadata,campaign_id,channel
    )
    select
      a.id,v_title,v_body,'admin_announcement',
      jsonb_strip_nulls(jsonb_build_object(
        'audience',p_audience,
        'zone_id',p_zone_id,
        'partner_id',p_partner_id,
        'campaign',true,
        'campaign_id',v_campaign,
        'environment',v_channel
      )),
      v_campaign,
      v_channel
    from audience_users a
    returning id,user_id
  )
  select
    (select count(*)::int from inserted),
    (select count(*)::int from audience_users where has_push)
  into v_count,v_push;

  update public.notification_campaigns
  set recipients_targeted=coalesce(v_count,0),
      push_enabled_recipients=coalesce(v_push,0)
  where id=v_campaign;

  perform public.admin_log_action(
    'send_announcement','notification_campaigns',v_campaign::text,
    jsonb_build_object(
      'environment',v_channel,
      'title',v_title,
      'recipients',v_count,
      'push_enabled',v_push,
      'audience',p_audience,
      'zone_id',p_zone_id,
      'partner_id',p_partner_id
    )
  );

  return jsonb_build_object(
    'campaign_id',v_campaign,
    'channel',v_channel,
    'recipients',coalesce(v_count,0),
    'push_enabled',coalesce(v_push,0),
    'audience',p_audience,
    'zone_id',p_zone_id,
    'partner_id',p_partner_id
  );
end;
$function$;
drop function if exists public.admin_operator_fare_list(uuid);
drop function if exists public.admin_operator_service_list();
drop function if exists public.admin_operator_upsert_fare_rule(uuid,uuid,text,numeric,numeric,numeric,numeric,numeric,numeric,boolean);
drop function if exists public.admin_operator_payment_overview(uuid,timestamptz,timestamptz,integer);
drop function if exists public.admin_operator_subscription_overview(uuid);
drop function if exists public.admin_operator_upsert_subscription_plan(bigint,uuid,text,text,numeric,integer,jsonb,boolean,integer);
commit;
