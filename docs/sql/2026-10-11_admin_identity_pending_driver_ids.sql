-- Aplicada en Supabase zgpijrznvaskgcmauwxx el 2026-10-11 (migración «admin_identity_pending_driver_ids»).
-- Solo lectura: devuelve los IDs de conductores con identidad manual por revisar.
-- Sin datos personales. Solo administradores (public.is_admin()).

create or replace function public.admin_identity_pending_driver_ids()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  return coalesce((
    select jsonb_agg(x.driver_id)
    from (
      select d.driver_id
      from public.driver_documents d
      where lower(coalesce(d.verification_method,'')) = 'manual'
        and lower(coalesce(d.document_type,'')) in ('identity_card','national_id','id_card','identity','carnet','cedula','cédula')
      group by d.driver_id
      having bool_or(lower(coalesce(d.status,'')) = 'pending')
         and not bool_or(lower(coalesce(d.status,'')) = 'verified')
    ) x
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_identity_pending_driver_ids() from public, anon;
grant execute on function public.admin_identity_pending_driver_ids() to authenticated;
