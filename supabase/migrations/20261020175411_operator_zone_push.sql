-- Notificaciones zonales: forzar zona de cuenta operadora.
-- No envía mensajes por sí misma; solo define controles de RPC.
-- Probar con audiencia de zona aislada antes de activar runtime_ready.
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
  if public.admin_zone_role_now()='zone_monitor' then
    raise exception 'El monitor no puede enviar notificaciones';
  end if;
  if public.admin_zone_role_now()='operator' then
    perform public.admin_operator_assert_module('notifications');
    p_zone_id:=public.admin_effective_zone_id(p_zone_id);
    if p_partner_id is not null and not exists(
       select 1 from public.partner_organizations p
       where p.id=p_partner_id and p.zone_id=p_zone_id
    ) then raise exception 'El socio no pertenece a tu zona'; end if;
  elsif not public.is_admin() then
    raise exception 'No autorizado';
  end if;
 -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  -- El rol y módulo fueron comprobados antes de seleccionar la audiencia.
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
      and (p_zone_id is null or (case when p_audience='drivers' then dp.zone_id when p_audience='passengers' then u.last_zone_id when dp.id is not null and dp.approval_status='approved' then dp.zone_id else u.last_zone_id end)=p_zone_id)
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

  if public.admin_zone_role_now()='operator' then
    insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,details)
    values(auth.uid(),'send_announcement','notification_campaigns',v_campaign::text,
      jsonb_build_object('environment',v_channel,'recipients',v_count,
        'push_enabled',v_push,'audience',p_audience,'zone_id',p_zone_id,
        'partner_id',p_partner_id));
  else
    perform public.admin_log_action(
      'send_announcement','notification_campaigns',v_campaign::text,
      jsonb_build_object('environment',v_channel,'recipients',v_count,
        'push_enabled',v_push,'audience',p_audience,'zone_id',p_zone_id,
        'partner_id',p_partner_id));
  end if;

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
  if public.admin_zone_role_now()='zone_monitor' then
    raise exception 'El monitor no puede enviar notificaciones';
  end if;
  if public.admin_zone_role_now()='operator' then
    perform public.admin_operator_assert_module('notifications');
    p_zone_id:=public.admin_effective_zone_id(p_zone_id);
    if p_partner_id is not null and not exists(
       select 1 from public.partner_organizations p
       where p.id=p_partner_id and p.zone_id=p_zone_id
    ) then raise exception 'El socio no pertenece a tu zona'; end if;
  elsif not public.is_admin() then
    raise exception 'No autorizado';
  end if;
 -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  -- El rol y módulo fueron comprobados antes de seleccionar la audiencia.
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
      and (p_zone_id is null or (case when p_audience='drivers' then dp.zone_id when p_audience='passengers' then u.last_zone_id when dp.id is not null and dp.approval_status='approved' then dp.zone_id else u.last_zone_id end)=p_zone_id)
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
  if public.admin_zone_role_now()='operator' then
   perform public.admin_operator_assert_module('notifications');
   p_zone_id:=public.admin_effective_zone_id(p_zone_id);
 elsif not public.is_admin() then
   raise exception 'No autorizado';
 end if;
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
        and ((public.admin_zone_role_now()='operator' and c.zone_id=p_zone_id) or (public.admin_zone_role_now()<>'operator' and (c.zone_id is null or c.zone_id=p_zone_id)))
        and (p_from is null or c.created_at>=p_from)
        and (p_to is null or c.created_at<p_to)
      order by c.created_at desc
      limit greatest(1,least(coalesce(p_limit,100),500))
    ) x
  );
end;
$function$;
