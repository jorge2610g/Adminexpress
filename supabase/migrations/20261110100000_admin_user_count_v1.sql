-- Total exacto de usuarios para el panel, con los mismos permisos y filtros
-- que admin_user_list_v4. Permite que la lista traiga solo 50 usuarios por
-- página y que el botón «Todos (N)» muestre el total real.
create or replace function public.admin_user_count_v1(
  p_channel text default 'production',
  p_zone_id uuid default null,
  p_search text default null
)
returns integer
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_channel text := public.normalize_runtime_channel(p_channel);
  v_zone uuid := public.admin_effective_zone_id(p_zone_id);
  v_search text := lower(trim(coalesce(p_search, '')));
begin
  perform public.admin_operator_assert_module('users');
  perform public.admin_assert_environment(public.normalize_runtime_channel(p_channel));
  return (
    select count(*)::integer
    from public.users u
    left join auth.users au on au.id = u.id
    left join public.driver_profiles d on d.id = u.id
    left join public.service_zones z on z.id = coalesce(u.last_zone_id, d.zone_id)
    left join public.account_runtime_bindings rb on rb.user_id = u.id
    where z.id = v_zone
      and public.normalize_runtime_channel(
        coalesce(
          rb.environment,
          case when exists(
            select 1
            from public.audit_test_group_members m
            join public.audit_test_groups g on g.id = m.group_id
            where m.user_id = u.id and m.enabled = true and g.active = true
          ) then 'preview' else 'production' end
        )
      ) = v_channel
      and (
        v_search = '' or
        lower(coalesce(u.full_name, '')) like '%' || v_search || '%' or
        lower(coalesce(au.email, '')) like '%' || v_search || '%' or
        lower(coalesce(u.phone, '')) like '%' || v_search || '%'
      )
  );
end;
$function$;

revoke all on function public.admin_user_count_v1(text, uuid, text) from public, anon;
grant execute on function public.admin_user_count_v1(text, uuid, text) to authenticated;
