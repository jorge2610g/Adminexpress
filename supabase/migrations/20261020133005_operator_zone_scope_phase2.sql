-- Fase 2: verificaciones por zona + permisos por modulo para RPC de detalle y escritura.
-- Reversible por migracion posterior. No modifica los datos ni los permisos del super_admin.
-- Operador solo en production. El monitor mantiene su comportamiento preexistente.
create or replace function public.admin_operator_assert_module(p_module text)
returns void language plpgsql stable security definer set search_path = ''
as $fn$
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
$fn$;
revoke all on function public.admin_operator_assert_module(text) from public, anon;
grant execute on function public.admin_operator_assert_module(text) to authenticated, service_role;

create or replace function public.admin_operator_assert_record(p_module text, p_kind text, p_id uuid)
returns uuid language plpgsql stable security definer set search_path = ''
as $fn$
declare v_role text; v_assigned uuid; v_target_zone uuid;
begin
  perform public.admin_operator_assert_module(p_module);
  select a.access_role, a.zone_id into v_role, v_assigned
  from public.admin_users a join public.users u on u.id=a.user_id
  where a.user_id=auth.uid() and a.active=true and u.account_status='active';
  if v_role <> 'operator' or v_assigned is null or p_id is null then
    raise exception 'Operacion reservada para operadores de zona';
  end if;
  if p_kind='user' and p_module='users' then
    select case when d.id is not null then d.zone_id else u.last_zone_id end
      into v_target_zone
    from public.users u left join public.driver_profiles d on d.id=u.id
    where u.id=p_id and public.admin_user_runtime_environment(u.id)='production';
  elsif p_kind='driver' and p_module='drivers' then
    select d.zone_id into v_target_zone
    from public.driver_profiles d
    where d.id=p_id and public.admin_user_runtime_environment(d.id)='production';
  elsif p_kind='trip' and p_module='trips' then
    select rr.zone_id into v_target_zone
    from public.trips t join public.ride_requests rr on rr.id=t.ride_request_id
    where t.id=p_id and t.channel='production' and rr.channel='production';
  elsif p_kind='merchant' and p_module='marketplace' then
    select m.zone_id into v_target_zone from public.marketplace_merchants m where m.id=p_id;
  elsif p_kind='partner' and p_module='partners' then
    select p.zone_id into v_target_zone from public.partner_organizations p where p.id=p_id;
  else
    raise exception 'Tipo de recurso o modulo no permitido';
  end if;
  if v_target_zone is null or v_assigned is distinct from v_target_zone then
    raise exception 'Registro fuera de la zona del operador';
  end if;
  return v_target_zone;
end;
$fn$;
revoke all on function public.admin_operator_assert_record(text,text,uuid) from public, anon;
grant execute on function public.admin_operator_assert_record(text,text,uuid) to authenticated, service_role;

-- Detalles limitados al ambito del operador; nunca retornan wallet, KYC,
-- documentos privados, tokens, metodos de pago ni datos de otras zonas.
create or replace function public.admin_operator_trip_detail(p_trip_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare v_result jsonb;
begin
  perform public.admin_operator_assert_record('trips','trip',p_trip_id);
  select jsonb_build_object(
    'trip',jsonb_build_object('id',t.id,'status',t.status,
      'final_fare',t.final_fare,'payment_status',t.payment_status,
      'created_at',t.created_at,'completed_at',t.completed_at),
    'request',jsonb_build_object('pickup_address',rr.pickup_address,
      'destination_address',rr.destination_address,'category',rr.category,
      'currency',rr.currency,'payment_method',rr.payment_method,'zone_id',rr.zone_id),
    'passenger',jsonb_build_object('id',pu.id,'full_name',pu.full_name,'phone',pu.phone),
    'driver',jsonb_build_object('id',du.id,'full_name',du.full_name,'phone',du.phone),
    'payments','[]'::jsonb,'wallet_movements','[]'::jsonb,
    'status_history','[]'::jsonb,'ratings','[]'::jsonb
  ) into v_result
  from public.trips t join public.ride_requests rr on rr.id=t.ride_request_id
  left join public.users pu on pu.id=t.passenger_id
  left join public.users du on du.id=t.driver_id where t.id=p_trip_id;
  return v_result;
end;
$fn$;

create or replace function public.admin_operator_user_detail(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare v_result jsonb;
begin
  perform public.admin_operator_assert_record('users','user',p_user_id);
  select jsonb_build_object(
    'user',jsonb_build_object('id',u.id,'full_name',u.full_name,
      'email',au.email,'phone',u.phone,'avatar_url',u.avatar_url,
      'active_mode',u.active_mode,'account_status',u.account_status,
      'last_zone_id',u.last_zone_id,'created_at',u.created_at),
    'driver',null,'wallet',null,'qa',null,'recent_trips','[]'::jsonb,
    'rating_summary',jsonb_build_object('role','passenger','count',0,'average',0)
  ) into v_result from public.users u left join auth.users au on au.id=u.id
  where u.id=p_user_id;
  return v_result;
end;
$fn$;

create or replace function public.admin_operator_driver_detail(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare v_result jsonb;
begin
  perform public.admin_operator_assert_record('drivers','driver',p_user_id);
  select jsonb_build_object(
    'user',jsonb_build_object('id',u.id,'full_name',u.full_name,'email',au.email,
      'phone',u.phone,'account_status',u.account_status,'last_zone_id',u.last_zone_id),
    'driver',jsonb_build_object('id',d.id,'zone_id',d.zone_id,
      'approval_status',d.approval_status,'online_status',d.online_status,
      'city',d.city,'vehicle_summary',d.vehicle_summary,
      'rating',d.rating,'completed_trips',d.completed_trips),
    'vehicles','[]'::jsonb,'documents','[]'::jsonb,
    'identity_verifications','[]'::jsonb,'subscription',null,'qa',null,
    'partner',null,'recent_trips','[]'::jsonb,
    'rating_summary',jsonb_build_object('role','driver','count',0,'average',d.rating)
  ) into v_result
  from public.driver_profiles d join public.users u on u.id=d.id
  left join auth.users au on au.id=d.id where d.id=p_user_id;
  return v_result;
end;
$fn$;

create or replace function public.admin_operator_merchant_detail(p_merchant_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare v_result jsonb;
begin
  perform public.admin_operator_assert_record('marketplace','merchant',p_merchant_id);
  select jsonb_build_object('merchant',jsonb_build_object(
    'id',m.id,'zone_id',m.zone_id,'name',m.name,'active',m.active),
    'products','[]'::jsonb)
    into v_result from public.marketplace_merchants m where m.id=p_merchant_id;
  return v_result;
end;
$fn$;

create or replace function public.admin_operator_partner_detail(p_partner_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare v_result jsonb;
begin
  perform public.admin_operator_assert_record('partners','partner',p_partner_id);
  select jsonb_build_object('partner',jsonb_build_object(
    'id',p.id,'zone_id',p.zone_id,'name',p.name,'status',p.status),
    'payments','[]'::jsonb,'settlements','[]'::jsonb)
    into v_result from public.partner_organizations p where p.id=p_partner_id;
  return v_result;
end;
$fn$;

-- Solo edicion de datos de contacto. Nunca modifica zona, aprobacion,
-- estado operativo, cuenta, vehiculos, documentos o fondos.
create or replace function public.admin_operator_update_contact(
  p_module text,p_user_id uuid,p_full_name text,p_phone text
) returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare v_user public.users%rowtype;
begin
  if p_module='drivers' then
    perform public.admin_operator_assert_record('drivers','driver',p_user_id);
  elsif p_module='users' then
    perform public.admin_operator_assert_record('users','user',p_user_id);
  else
    raise exception 'Modulo no modificable';
  end if;
  if exists(select 1 from public.admin_users a where a.user_id=p_user_id) then
    raise exception 'No se puede modificar otra cuenta administrativa';
  end if;
  if nullif(trim(coalesce(p_full_name,'')),'') is null then
    raise exception 'Nombre requerido';
  end if;
  update public.users set full_name=trim(p_full_name),phone=nullif(trim(coalesce(p_phone,'')),''),
    updated_at=now() where id=p_user_id returning * into v_user;
  if not found then raise exception 'Usuario no encontrado'; end if;
  insert into public.admin_audit_log(admin_user_id,action,entity_type,entity_id,details)
  values(auth.uid(),'operator_contact_update','user',p_user_id::text,
    jsonb_build_object('module',p_module,'zone_id',
      case when p_module='drivers' then
        (select d.zone_id from public.driver_profiles d where d.id=p_user_id)
      else v_user.last_zone_id end));
  return jsonb_build_object('id',v_user.id,'full_name',v_user.full_name,
    'phone',v_user.phone,'account_status',v_user.account_status,
    'active_mode',v_user.active_mode,'last_zone_id',v_user.last_zone_id);
end;
$fn$;

-- Compatibilidad v2: administrador central sigue usando los RPC existentes;
-- el operador usa respuestas acotadas y validaciones sobre ids efectivos.
create or replace function public.admin_user_detail_v2(p_user_id uuid,p_channel text)
returns jsonb language plpgsql security definer set search_path = 'public'
as $fn$
begin
  perform public.admin_assert_target_environment(p_user_id,p_channel);
  if public.admin_zone_role_now()='operator' then
    if lower(trim(p_channel)) <> 'production' then raise exception 'Entorno no permitido'; end if;
    return public.admin_operator_user_detail(p_user_id);
  end if;
  return public.admin_user_detail(p_user_id);
end;
$fn$;

create or replace function public.admin_driver_detail_v2(p_user_id uuid,p_channel text)
returns jsonb language plpgsql security definer set search_path = 'public'
as $fn$
begin
  perform public.admin_assert_target_environment(p_user_id,p_channel);
  if public.admin_zone_role_now()='operator' then
    if lower(trim(p_channel)) <> 'production' then raise exception 'Entorno no permitido'; end if;
    return public.admin_operator_driver_detail(p_user_id);
  end if;
  return public.admin_driver_detail(p_user_id);
end;
$fn$;

create or replace function public.admin_trip_detail_v2(p_trip_id uuid,p_channel text)
returns jsonb language plpgsql security definer set search_path = 'public'
as $fn$
declare v_channel text:=public.admin_assert_environment(p_channel);
v_trip_channel text;
begin
  select lower(coalesce(nullif(trim(t.channel),''),'production'))
    into v_trip_channel from public.trips t where t.id=p_trip_id;
  if v_trip_channel is null then raise exception 'Viaje no encontrado'; end if;
  if v_trip_channel <> v_channel then
    raise exception 'El viaje pertenece a % y el panel esta en %',v_trip_channel,v_channel;
  end if;
  if public.admin_zone_role_now()='operator' then
    if v_channel <> 'production' then raise exception 'Entorno no permitido'; end if;
    return public.admin_operator_trip_detail(p_trip_id);
  end if;
  return public.admin_trip_detail(p_trip_id);
end;
$fn$;

-- Edicion de usuario: operador no puede alterar modo, estado ni zona.
create or replace function public.admin_update_user_profile_v2(
  p_user_id uuid,p_full_name text,p_phone text,p_active_mode text,
  p_account_status text,p_zone_id uuid,p_channel text
) returns jsonb language plpgsql security definer set search_path = 'public'
as $fn$
declare v_result jsonb; v_current public.users%rowtype;
begin
  perform public.admin_assert_target_environment(p_user_id,p_channel);
  if public.admin_zone_role_now()='operator' then
    perform public.admin_operator_assert_record('users','user',p_user_id);
    select * into v_current from public.users where id=p_user_id for update;
    if p_zone_id is distinct from v_current.last_zone_id
       or p_active_mode is distinct from v_current.active_mode
       or p_account_status is distinct from v_current.account_status then
      raise exception 'Solo puedes actualizar datos de contacto dentro de tu zona';
    end if;
    return public.admin_operator_update_contact('users',p_user_id,p_full_name,p_phone);
  end if;
  v_result:=public.admin_update_user_profile(
    p_user_id,p_full_name,p_phone,p_active_mode,p_account_status,p_zone_id);
  perform public.admin_log_action('admin_scope_confirmed','user',p_user_id::text,
    jsonb_build_object('environment',lower(trim(p_channel))));
  return v_result;
end;
$fn$;

-- LISTAS: asegurar modulos autorizados, ademas de la zona implementada en fase 1.
-- Central y monitor conservan exactamente el flujo anterior.
do $patch$
declare r record; v_def text; v_pos int; v_begin constant text:=E'\nbegin\n'; v_module text;
begin
  for r in select p.oid,p.proname,pg_get_functiondef(p.oid) as def
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in
      ('admin_user_list_v4','admin_driver_list_v3','admin_trip_list_v4',
       'admin_delivery_list_v4','admin_marketplace_orders_v2','admin_dashboard_state_v2')
  loop
    v_def:=r.def;
    if position('admin_operator_assert_module' in v_def)>0 then continue; end if;
    v_module:=case r.proname
      when 'admin_dashboard_state_v2' then 'dashboard'
      when 'admin_user_list_v4' then 'users'
      when 'admin_driver_list_v3' then 'drivers'
      when 'admin_trip_list_v4' then 'trips'
      when 'admin_delivery_list_v4' then 'delivery'
      when 'admin_marketplace_orders_v2' then 'delivery_orders' end;
    v_pos:=position(v_begin in lower(v_def));
    if v_pos=0 then raise exception 'No se puede insertar control de modulo en %',r.proname; end if;
    execute substr(v_def,1,v_pos+length(v_begin)-1)
      || '  perform public.admin_operator_assert_module(''' || v_module || ''');' || E'\n'
      || substr(v_def,v_pos+length(v_begin));
  end loop;
end;
$patch$;

-- Privilegios: todas las funciones nuevas requieren sesion autenticada.
revoke all on function public.admin_operator_trip_detail(uuid) from public,anon;
revoke all on function public.admin_operator_user_detail(uuid) from public,anon;
revoke all on function public.admin_operator_driver_detail(uuid) from public,anon;
revoke all on function public.admin_operator_merchant_detail(uuid) from public,anon;
revoke all on function public.admin_operator_partner_detail(uuid) from public,anon;
revoke all on function public.admin_operator_update_contact(text,uuid,text,text) from public,anon;
grant execute on function public.admin_operator_trip_detail(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_user_detail(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_driver_detail(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_merchant_detail(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_partner_detail(uuid) to authenticated,service_role;
grant execute on function public.admin_operator_update_contact(text,uuid,text,text) to authenticated,service_role;
