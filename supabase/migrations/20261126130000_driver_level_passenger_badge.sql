-- Fase 3 niveles: insignia del nivel visible al pasajero en el perfil del conductor.
-- Apagada por defecto (passenger_badge_enabled=false): sin efecto hasta que el administrador la active.
alter table public.driver_level_settings
  add column if not exists passenger_badge_enabled boolean not null default false;

do $$
declare d text; r text;
begin
  d := pg_get_functiondef('public.admin_driver_level_settings_update_v1(jsonb)'::regprocedure);
  r := replace(d,
    'dispatch_priority_enabled = coalesce((p->>''dispatch_priority_enabled'')::boolean, s.dispatch_priority_enabled),',
    'dispatch_priority_enabled = coalesce((p->>''dispatch_priority_enabled'')::boolean, s.dispatch_priority_enabled), passenger_badge_enabled = coalesce((p->>''passenger_badge_enabled'')::boolean, s.passenger_badge_enabled),');
  if r = d then raise exception 'ancla update no encontrada'; end if;
  execute r;

  d := pg_get_functiondef('public.driver_profile_for_viewer(uuid)'::regprocedure);
  r := replace(d, '''id'',v_row.id,',
    '''driver_level'', (select case when s.enabled and s.passenger_badge_enabled then nullif(public.driver_level_for_list(v_row.id, coalesce((select b.environment from public.account_runtime_bindings b where b.user_id = v_row.id limit 1), ''production'')), ''inicio'') else null end from public.driver_level_settings s where s.id), ''id'',v_row.id,');
  if r = d then raise exception 'ancla perfil no encontrada'; end if;
  execute r;
end $$;
