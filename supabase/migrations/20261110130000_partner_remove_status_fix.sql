-- «Quitar del sindicato» enviaba el estado 'removed', que no está permitido por
-- driver_partner_memberships_status_check (solo active, ended, suspended).
-- Ahora se guarda 'ended' con la fecha de salida; el resto del comportamiento
-- no cambia: se libera el número de socio y deja de aparecer en la lista.

create or replace function public.partner_set_membership_status(
  p_partner_id uuid,
  p_driver_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_runtime jsonb;
  v_channel text;
begin
  if auth.uid() is null or (not public.is_admin() and not exists (
    select 1 from public.partner_members pm
    where pm.partner_id = p_partner_id
      and pm.user_id = auth.uid()
      and pm.active
      and pm.role in ('owner', 'manager')
  )) then
    raise exception 'No autorizado';
  end if;
  v_runtime := public.resolve_current_runtime_environment();
  if coalesce((v_runtime->>'allowed')::boolean, false) = false then
    raise exception 'Entorno no autorizado';
  end if;
  v_channel := v_runtime->>'environment';
  if p_status not in ('active', 'suspended', 'removed') then
    raise exception 'Estado inválido';
  end if;
  update public.driver_partner_memberships
  set status = case when p_status = 'removed' then 'ended' else p_status end,
      ended_at = case
        when p_status = 'removed' then now()
        when p_status = 'active' then null
        else ended_at
      end,
      member_number = case when p_status = 'removed' then null else member_number end
  where partner_id = p_partner_id
    and driver_id = p_driver_id
    and channel = v_channel;
  if not found then
    raise exception 'El conductor no pertenece al sindicato';
  end if;
end
$function$;
