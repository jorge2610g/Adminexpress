-- Foto del asesor para la credencial impresa. Bucket privado; solo super admin.
alter table public.sales_advisors add column if not exists photo_path text;

insert into storage.buckets (id, name, public)
  values ('sales-advisor-photos', 'sales-advisor-photos', false)
  on conflict (id) do nothing;

drop policy if exists sales_advisor_photos_admin_all on storage.objects;
create policy sales_advisor_photos_admin_all on storage.objects
  for all to authenticated
  using (bucket_id = 'sales-advisor-photos' and public.is_admin())
  with check (bucket_id = 'sales-advisor-photos' and public.is_admin());

create or replace function public.admin_sales_set_advisor_photo(p_id uuid, p_path text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  if p_path is null or split_part(p_path, '/', 1) <> p_id::text then
    raise exception 'Foto inválida';
  end if;
  update public.sales_advisors set photo_path = p_path where id = p_id;
  if not found then
    raise exception 'Asesor no encontrado';
  end if;
  perform public.admin_log_action('sales_advisor_photo', 'sales_advisors', p_id::text,
    jsonb_build_object('path', p_path));
end
$$;

create or replace function public.admin_sales_advisor_credential(p_id uuid)
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
  return (
    select jsonb_build_object(
      'name', a.full_name,
      'code', a.code,
      'active', a.active,
      'photo_path', a.photo_path
    )
    from public.sales_advisors a
    where a.id = p_id
  );
end
$$;

revoke all on function public.admin_sales_set_advisor_photo(uuid, text) from public, anon;
revoke all on function public.admin_sales_advisor_credential(uuid) from public, anon;
grant execute on function public.admin_sales_set_advisor_photo(uuid, text) to authenticated;
grant execute on function public.admin_sales_advisor_credential(uuid) to authenticated;
