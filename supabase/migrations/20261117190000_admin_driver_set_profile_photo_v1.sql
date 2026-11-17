-- Administrador: cambiar la foto de perfil de un conductor desde el panel.
-- Aditiva. El administrador (super_admin, igual que los perfiles) solo puede
-- subir a la carpeta profile/ de un conductor y solo puede apuntar la foto de
-- perfil a un objeto de esa carpeta. Deja registro en la bitácora con la foto
-- anterior. No modifica el disparador de selfie de Bolivia.

drop policy if exists driver_onboarding_admin_insert_profile on storage.objects;
create policy driver_onboarding_admin_insert_profile
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'driver-onboarding'
  and public.is_admin()
  and (storage.foldername(name))[2] = 'profile'
);

create or replace function public.admin_driver_set_profile_photo_v1(
  p_driver_id uuid,
  p_object_path text,
  p_channel text
)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_path text := btrim(coalesce(p_object_path, ''));
  v_before text;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  perform public.admin_assert_target_environment(p_driver_id, p_channel);

  if v_path = ''
     or split_part(v_path, '/', 1) <> p_driver_id::text
     or split_part(v_path, '/', 2) <> 'profile'
     or v_path like '%..%' then
    raise exception 'Ruta de foto inválida';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'driver-onboarding' and o.name = v_path
  ) then
    raise exception 'La foto no se encontró';
  end if;

  select dp.profile_photo_path into v_before
  from public.driver_profiles dp
  where dp.id = p_driver_id
  for update;
  if not found then
    raise exception 'Conductor no encontrado';
  end if;

  update public.driver_profiles
  set profile_photo_path = v_path,
      updated_at = now()
  where id = p_driver_id;

  perform public.admin_log_action(
    'driver_profile_photo_replaced',
    'driver_profile',
    p_driver_id::text,
    jsonb_build_object(
      'environment', lower(trim(p_channel)),
      'before', v_before,
      'after', v_path
    )
  );

  return jsonb_build_object(
    'driver_id', p_driver_id,
    'profile_photo_path', v_path
  );
end;
$$;

revoke execute on function public.admin_driver_set_profile_photo_v1(uuid, text, text) from public, anon;
grant execute on function public.admin_driver_set_profile_photo_v1(uuid, text, text) to authenticated;
