-- Panel: administrar tarifas por horario (tarifa nocturna, de madrugada, etc.).
-- Requiere la migración 20261119120000_fare_time_rules del proyecto de
-- pasajeros y conductores (tabla fare_time_rules y effective_fare_rule_at).
--
-- Escrituras solo en Producción: Preview usa su copia aislada en el panel y
-- nunca modifica las tarifas reales.

create or replace function public.admin_fare_time_rules_list(
  p_zone_id uuid,
  p_service_key text default null,
  p_channel text default 'production'
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null or not public.is_admin()
     or p_channel not in ('preview', 'production')
     or not public.admin_environment_allowed(p_channel) then
    raise exception 'Acceso no autorizado a tarifas';
  end if;
  p_zone_id := public.admin_scope_zone(p_zone_id);

  return jsonb_build_object(
    'zone_id', p_zone_id,
    'timezone', (select coalesce(z.timezone, 'America/La_Paz')
                   from public.service_zones z where z.id = p_zone_id),
    'currency', (select z.currency_code
                   from public.service_zones z where z.id = p_zone_id),
    'rules', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id,
        'service_key', t.service_key,
        'name', t.name,
        'start_time', to_char(t.start_time, 'HH24:MI'),
        'end_time', to_char(t.end_time, 'HH24:MI'),
        'days_of_week', to_jsonb(t.days_of_week),
        'base_fare', t.base_fare,
        'per_km', t.per_km,
        'per_minute', t.per_minute,
        'minimum_fare', t.minimum_fare,
        'active', t.active
      ) order by t.start_time, t.name), '[]'::jsonb)
      from public.fare_time_rules t
      where t.zone_id = p_zone_id
        and (p_service_key is null or t.service_key = p_service_key)
    )
  );
end;
$$;

create or replace function public.admin_fare_time_rule_upsert(
  p_id uuid,
  p_zone_id uuid,
  p_service_key text,
  p_name text,
  p_start_time text,
  p_end_time text,
  p_days integer[],
  p_base_fare numeric,
  p_per_km numeric,
  p_per_minute numeric,
  p_minimum_fare numeric,
  p_active boolean default true,
  p_channel text default 'production'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_service text := btrim(coalesce(p_service_key, ''));
  v_start time;
  v_end time;
  v_days smallint[];
  v_base numeric := coalesce(p_base_fare, 0);
  v_km numeric := coalesce(p_per_km, 0);
  v_min numeric := coalesce(p_per_minute, 0);
  v_minimum numeric := coalesce(p_minimum_fare, 0);
  v_active boolean := coalesce(p_active, true);
  v_id uuid;
  v_clash text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  perform public.admin_assert_environment('production');
  if p_channel is distinct from 'production' then
    raise exception 'Las tarifas por horario solo se guardan en Producción';
  end if;
  p_zone_id := public.admin_scope_zone(p_zone_id);

  if v_name = '' or char_length(v_name) > 60 then
    raise exception 'Escribe un nombre de hasta 60 caracteres';
  end if;
  if not exists (
    select 1 from public.zone_service_catalog zs
    where zs.zone_id = p_zone_id and zs.service_key = v_service
  ) then
    raise exception 'La zona o servicio no existe';
  end if;

  begin
    v_start := p_start_time::time;
    v_end := p_end_time::time;
  exception when others then
    raise exception 'Hora inválida. Usa el formato HH:MM';
  end;
  if v_start = v_end then
    raise exception 'La hora de inicio y la de fin no pueden ser iguales';
  end if;

  if p_days is null or cardinality(p_days) = 0
     or exists (select 1 from unnest(p_days) d where d < 1 or d > 7) then
    raise exception 'Elige al menos un día de la semana';
  end if;
  select array_agg(distinct d::smallint order by d::smallint)
    into v_days from unnest(p_days) d;

  if v_base < 0 or v_km < 0 or v_min < 0 or v_minimum < 0
     or v_base > 100000000 or v_km > 100000000
     or v_min > 100000000 or v_minimum > 100000000 then
    raise exception 'Los montos deben estar entre 0 y 100000000';
  end if;
  if v_base + v_km + v_min + v_minimum <= 0 then
    raise exception 'La tarifa debe tener al menos un monto mayor a 0';
  end if;

  if (select count(*) from public.fare_time_rules t
       where t.zone_id = p_zone_id and t.service_key = v_service
         and t.id is distinct from p_id) >= 20 then
    raise exception 'Máximo 20 tarifas por horario por servicio';
  end if;

  -- Dos tarifas activas no pueden cubrir la misma hora del mismo día.
  -- 2024-01-01 es lunes (ISO 1): se recorre una semana minuto a minuto.
  if v_active then
    select t.name into v_clash
    from public.fare_time_rules t
    where t.zone_id = p_zone_id and t.service_key = v_service
      and t.active and t.id is distinct from p_id
      and exists (
        select 1
        from generate_series(0, 10079) m,
        lateral (select (date '2024-01-01'
                         + (m / 1440) * interval '1 day'
                         + (m % 1440) * interval '1 minute') as ts) x
        where public.fare_time_rule_matches(
                t.start_time, t.end_time, t.days_of_week, x.ts)
          and public.fare_time_rule_matches(v_start, v_end, v_days, x.ts)
      )
    limit 1;
    if v_clash is not null then
      raise exception 'El horario se cruza con la tarifa «%»', v_clash;
    end if;
  end if;

  if p_id is null then
    insert into public.fare_time_rules(
      zone_id, service_key, name, start_time, end_time, days_of_week,
      base_fare, per_km, per_minute, minimum_fare, active)
    values (
      p_zone_id, v_service, v_name, v_start, v_end, v_days,
      v_base, v_km, v_min, v_minimum, v_active)
    returning id into v_id;
  else
    update public.fare_time_rules
       set service_key = v_service, name = v_name,
           start_time = v_start, end_time = v_end, days_of_week = v_days,
           base_fare = v_base, per_km = v_km, per_minute = v_min,
           minimum_fare = v_minimum, active = v_active, updated_at = now()
     where id = p_id and zone_id = p_zone_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Tarifa no encontrada';
    end if;
  end if;

  perform public.admin_log_action(
    'fare_time_rule_saved', 'fare_time_rule', v_id::text,
    jsonb_build_object(
      'zone_id', p_zone_id, 'service_key', v_service, 'name', v_name,
      'start_time', to_char(v_start, 'HH24:MI'),
      'end_time', to_char(v_end, 'HH24:MI'),
      'days_of_week', to_jsonb(v_days),
      'base_fare', v_base, 'per_km', v_km, 'per_minute', v_min,
      'minimum_fare', v_minimum, 'active', v_active));

  return public.admin_fare_time_rules_list(p_zone_id, v_service, 'production');
end;
$$;

create or replace function public.admin_fare_time_rule_delete(
  p_id uuid,
  p_channel text default 'production'
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_row public.fare_time_rules%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  perform public.admin_assert_environment('production');
  if p_channel is distinct from 'production' then
    raise exception 'Las tarifas por horario solo se borran en Producción';
  end if;

  select * into v_row from public.fare_time_rules where id = p_id;
  if not found then
    raise exception 'Tarifa no encontrada';
  end if;
  perform public.admin_scope_zone(v_row.zone_id);

  delete from public.fare_time_rules where id = p_id;

  perform public.admin_log_action(
    'fare_time_rule_deleted', 'fare_time_rule', p_id::text,
    jsonb_build_object(
      'zone_id', v_row.zone_id, 'service_key', v_row.service_key,
      'name', v_row.name));
  return true;
end;
$$;

revoke execute on function public.admin_fare_time_rules_list(uuid, text, text)
  from public, anon;
revoke execute on function public.admin_fare_time_rule_upsert(
  uuid, uuid, text, text, text, text, integer[], numeric, numeric, numeric,
  numeric, boolean, text) from public, anon;
revoke execute on function public.admin_fare_time_rule_delete(uuid, text)
  from public, anon;
grant execute on function public.admin_fare_time_rules_list(uuid, text, text)
  to authenticated;
grant execute on function public.admin_fare_time_rule_upsert(
  uuid, uuid, text, text, text, text, integer[], numeric, numeric, numeric,
  numeric, boolean, text) to authenticated;
grant execute on function public.admin_fare_time_rule_delete(uuid, text)
  to authenticated;
