-- Fail-closed rollback: disable authenticated banner RPC access rather than
-- restoring the prior functions, which lacked the delegated module check.
-- Central banner operations remain unavailable until the forward fix is
-- reapplied; this rollback intentionally does not reopen the authorization gap.
begin;

revoke all on function public.admin_landing_banner_save_v1(
  uuid, uuid, text, text, text, text, text, text, text, text, boolean,
  integer, timestamp with time zone, timestamp with time zone
) from public, anon, authenticated;

revoke all on function public.admin_landing_banners_list_v1(uuid, text)
  from public, anon, authenticated;

grant execute on function public.admin_landing_banner_save_v1(
  uuid, uuid, text, text, text, text, text, text, text, text, boolean,
  integer, timestamp with time zone, timestamp with time zone
) to service_role;

grant execute on function public.admin_landing_banners_list_v1(uuid, text)
  to service_role;

commit;
