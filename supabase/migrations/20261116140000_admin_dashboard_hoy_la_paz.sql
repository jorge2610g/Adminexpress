-- Día de «hoy» del dashboard en hora de La Paz (Bolivia, UTC−4).
--
-- admin_dashboard_state_v2 calculaba el inicio del día con date_trunc('day', now()),
-- que usa la zona de la sesión (UTC en Supabase). Eso reiniciaba los contadores
-- a las 20:00 de Bolivia. Ahora el día empieza a las 00:00 de America/La_Paz.
--
-- Solo cambia esa línea. La función se reconstruye desde su definición actual y se
-- verifica que el texto a reemplazar aparezca exactamente una vez.
-- No cambia permisos ni la lógica de los contadores (completados siguen por fecha
-- de finalización).

do $$
declare
  v_src text;
  v_old text := $a$date_trunc('day',now())$a$;
  v_new text := $a$date_trunc('day', now() at time zone 'America/La_Paz') at time zone 'America/La_Paz'$a$;
begin
  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'admin_dashboard_state_v2';

  if v_src is null then
    raise exception 'admin_dashboard_state_v2 no existe';
  end if;
  if (length(v_src) - length(replace(v_src, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'La línea de corte no aparece exactamente una vez: no se aplica';
  end if;
  execute replace(v_src, v_old, v_new);
end
$$;
