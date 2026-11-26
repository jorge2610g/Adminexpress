-- La lista de solicitudes del conductor es una función STABLE (solo lectura) y la fase 2 la hizo llamar a
-- driver_level_cached, que escribe en la caché: la app mostraba «cannot execute INSERT in a read-only
-- transaction». La lista usa ahora una versión de solo lectura.
create or replace function public.driver_level_for_list(p_driver uuid, p_channel text)
returns text language plpgsql stable security definer set search_path to 'public' as $$
declare v_channel text := public.normalize_runtime_channel(p_channel); c public.driver_level_cache%rowtype;
begin
  select * into c from public.driver_level_cache where driver_id = p_driver and channel = v_channel;
  if c.driver_id is not null and c.computed_at > now() - interval '30 minutes' then return c.level; end if;
  begin
    return coalesce(public.driver_level_compute(p_driver, v_channel)->>'level', 'inicio');
  exception when others then
    return coalesce(c.level, 'inicio');
  end;
end $$;
revoke all on function public.driver_level_for_list(uuid, text) from public, anon, authenticated;

do $m$
declare d text;
begin
  d := pg_get_functiondef('public.available_ride_requests_for_driver_v2(text)'::regprocedure);
  if position('public.driver_level_cached(v_uid, v_channel)' in d) > 0 then
    d := replace(d, 'public.driver_level_cached(v_uid, v_channel)', 'public.driver_level_for_list(v_uid, v_channel)');
    execute d;
  end if;
end $m$;
