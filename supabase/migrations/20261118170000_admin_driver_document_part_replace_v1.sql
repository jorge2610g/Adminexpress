-- Administrador: actualizar (reemplazar) una parte de un documento ya cargado por
-- el conductor (anverso, reverso o selfie). No agrega documentos nuevos: cambia la
-- ruta de la parte existente. Solo super_admin, mismo control que los perfiles.
-- Aditiva. Deja registro con la ruta anterior.

drop policy if exists driver_onboarding_admin_insert_profile on storage.objects;
create policy driver_onboarding_admin_insert_profile
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'driver-onboarding'
  and public.is_admin()
  and (storage.foldername(name))[2] in ('profile', 'documents')
);

create or replace function public.admin_driver_document_part_replace_v1(
  p_document_id uuid,
  p_slot text,
  p_path text,
  p_channel text
)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_doc public.driver_documents%rowtype;
  v_slot text := lower(btrim(coalesce(p_slot, '')));
  v_path text := btrim(coalesce(p_path, ''));
  v_before text;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  if v_slot not in ('front', 'back', 'selfie') then
    raise exception 'Parte de documento inválida';
  end if;

  select * into v_doc
  from public.driver_documents
  where id = p_document_id
  for update;
  if not found then
    raise exception 'Documento no encontrado';
  end if;

  perform public.admin_assert_target_environment(v_doc.driver_id, p_channel);

  if v_path = ''
     or split_part(v_path, '/', 1) <> v_doc.driver_id::text
     or split_part(v_path, '/', 2) <> 'documents'
     or v_path like '%..%' then
    raise exception 'Ruta de documento inválida';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'driver-onboarding' and o.name = v_path
  ) then
    raise exception 'El archivo no se encontró';
  end if;

  v_before := case v_slot
    when 'front' then v_doc.front_object_path
    when 'back' then v_doc.back_object_path
    else v_doc.selfie_object_path
  end;

  update public.driver_documents
  set front_object_path = case when v_slot = 'front' then v_path else front_object_path end,
      back_object_path = case when v_slot = 'back' then v_path else back_object_path end,
      selfie_object_path = case when v_slot = 'selfie' then v_path else selfie_object_path end,
      updated_at = now()
  where id = p_document_id;

  perform public.admin_log_action(
    'driver_document_part_replaced',
    'driver_document',
    p_document_id::text,
    jsonb_build_object(
      'environment', lower(trim(p_channel)),
      'driver_id', v_doc.driver_id,
      'slot', v_slot,
      'before', v_before,
      'after', v_path
    )
  );

  return jsonb_build_object(
    'document_id', p_document_id,
    'slot', v_slot,
    'path', v_path
  );
end;
$$;

revoke execute on function public.admin_driver_document_part_replace_v1(uuid, text, text, text) from public, anon;
grant execute on function public.admin_driver_document_part_replace_v1(uuid, text, text, text) to authenticated;
