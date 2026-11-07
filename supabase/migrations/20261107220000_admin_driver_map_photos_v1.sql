-- Fotos de perfil de conductores para el mapa de operaciones del panel.
-- Solo lectura. Devuelve la ruta privada de la foto (bucket driver-onboarding) únicamente
-- para los conductores que admin_driver_list_v3 ya deja ver a esta cuenta, con los mismos
-- controles de módulo, entorno y zona que el tablero operativo. El panel firma la URL en
-- el cliente con caducidad corta; este RPC no expone ninguna URL.

begin;

create or replace function public.admin_driver_map_photos_v1(
  p_channel text default 'production',
  p_zone_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
begin
  perform public.admin_operator_assert_module('dashboard');
  -- Control 2026-10-15: el entorno debe estar permitido a esta cuenta
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id', dp.id,
          'photo_path', dp.profile_photo_path
        )
        order by dp.id
      ),
      '[]'::jsonb
    )
    from public.driver_profiles dp
    where nullif(btrim(dp.profile_photo_path), '') is not null
      and dp.id in (
        select (x->>'user_id')::uuid
        from jsonb_array_elements(public.admin_driver_list_v3(v_channel, v_zone)) x
      )
  );
end;
$$;

revoke all on function public.admin_driver_map_photos_v1(text, uuid) from public, anon;
grant execute on function public.admin_driver_map_photos_v1(text, uuid) to authenticated;

commit;
