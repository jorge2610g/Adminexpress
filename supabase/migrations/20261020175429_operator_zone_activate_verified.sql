-- Se habilitan únicamente los cuatro módulos con RPC zonales y QA
-- en transacciones reversibles. Los demás quedan deshabilitados en runtime.
do $ready$
declare v_updated integer;
begin
 update public.admin_operator_module_capabilities
 set runtime_ready=true,updated_at=now()
 where module_key in ('fares','subscriptions','payments','notifications');
 get diagnostics v_updated=row_count;
 if v_updated<>4 then
   raise exception 'No se pudo activar exactamente cuatro capacidades zonales';
 end if;
end
$ready$;
