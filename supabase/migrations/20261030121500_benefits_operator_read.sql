-- Benefits are configurable only by superadmins. Operators receive scoped
-- read access after this capability is marked runtime ready by a later QA step.
begin;
insert into public.admin_operator_module_capabilities(module_key,runtime_ready)
values('benefits',false)
on conflict(module_key) do nothing;
commit;
