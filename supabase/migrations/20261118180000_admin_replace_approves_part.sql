-- Cuando el administrador actualiza un documento o la foto de perfil, la nueva
-- parte queda aprobada automáticamente. Los disparadores de estado reinician a
-- pendiente cualquier parte cuya ruta cambia; por eso la RPC escribe también la
-- decisión de revisión con la ruta nueva. Como la ruta ya coincide, el
-- disparador conserva la aprobación. La foto de perfil se aprueba en el
-- documento de identidad manual más reciente, igual que el disparador de sincronía.

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
  v_version integer;
  v_entry jsonb;
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

  v_version := coalesce(nullif(v_doc.review_parts->v_slot->>'version', '')::integer, 0) + 1;
  v_entry := jsonb_build_object(
    'status', 'approved',
    'reason', null,
    'path', v_path,
    'version', v_version,
    'reviewed_at', now(),
    'reviewed_by', auth.uid()
  );

  update public.driver_documents
  set front_object_path = case when v_slot = 'front' then v_path else front_object_path end,
      back_object_path = case when v_slot = 'back' then v_path else back_object_path end,
      selfie_object_path = case when v_slot = 'selfie' then v_path else selfie_object_path end,
      review_parts = jsonb_set(coalesce(review_parts, '{}'::jsonb), array[v_slot], v_entry, true),
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
      'after', v_path,
      'status', 'approved'
    )
  );

  return jsonb_build_object(
    'document_id', p_document_id,
    'slot', v_slot,
    'path', v_path,
    'status', 'approved'
  );
end;
$$;

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
  v_doc_id uuid;
  v_version integer;
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

  -- Aprobar la foto en el documento de identidad manual más reciente del conductor.
  select d.id into v_doc_id
  from public.driver_documents d
  join public.driver_document_requirements r on r.id = d.requirement_id
  where d.driver_id = p_driver_id
    and d.verification_method = 'manual'
    and lower(coalesce(r.code, '')) in ('identity_card','national_id','id_card','identity','carnet','cedula','cédula')
  order by d.updated_at desc
  limit 1;

  if v_doc_id is not null then
    select coalesce(nullif(review_parts->'profile'->>'version', '')::integer, 0) + 1
    into v_version
    from public.driver_documents
    where id = v_doc_id;

    update public.driver_documents
    set review_parts = jsonb_set(
          coalesce(review_parts, '{}'::jsonb),
          '{profile}',
          jsonb_build_object(
            'status', 'approved',
            'reason', null,
            'path', v_path,
            'version', v_version,
            'reviewed_at', now(),
            'reviewed_by', auth.uid()
          ),
          true
        ),
        updated_at = now()
    where id = v_doc_id;
  end if;

  perform public.admin_log_action(
    'driver_profile_photo_replaced',
    'driver_profile',
    p_driver_id::text,
    jsonb_build_object(
      'environment', lower(trim(p_channel)),
      'before', v_before,
      'after', v_path,
      'status', 'approved'
    )
  );

  return jsonb_build_object(
    'driver_id', p_driver_id,
    'profile_photo_path', v_path,
    'status', 'approved'
  );
end;
$$;
