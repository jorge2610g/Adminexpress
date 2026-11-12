-- Autocompletado del correo al crear un asesor: busca cuentas Express
-- existentes por correo o nombre. Solo super admin, mínimo 3 caracteres,
-- máximo 8 resultados.
create or replace function public.admin_sales_find_accounts(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_q text := lower(trim(coalesce(p_query, '')));
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  if char_length(v_q) < 3 then
    return '[]'::jsonb;
  end if;
  return (
    select coalesce(jsonb_agg(x.row order by x.email), '[]'::jsonb)
    from (
      select
        au.email::text as email,
        jsonb_build_object(
          'email', au.email,
          'name', coalesce(u.full_name, ''),
          'already_advisor', exists (select 1 from public.sales_advisors a where a.user_id = au.id)
        ) as row
      from auth.users au
      left join public.users u on u.id = au.id
      where au.email is not null
        and (lower(au.email) like '%' || v_q || '%' or lower(coalesce(u.full_name, '')) like '%' || v_q || '%')
      order by au.email
      limit 8
    ) x
  );
end
$$;

revoke all on function public.admin_sales_find_accounts(text) from public, anon;
grant execute on function public.admin_sales_find_accounts(text) to authenticated;
