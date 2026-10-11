-- Express Admin Preview with ONE shared Supabase project.
-- This migration only ADDS a QA-only, read-only RPC. No tables or production
-- business data are changed. Run only on zgpijrznvaskgcmauwxx after reviewing.
-- Never expose live driver subscriptions to Preview clients.
CREATE OR REPLACE FUNCTION public.admin_preview_driver_subscription_candidates(
    p_zone_id uuid,
    p_search text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_role text;
  v_admin_zone uuid;
  v_search text := left(trim(coalesce(p_search,'')),120);
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin()
     OR NOT public.admin_environment_allowed('preview') THEN
    RAISE EXCEPTION 'No autorizado para consultar conductores QA';
  END IF;
  IF p_zone_id IS NULL THEN
    RAISE EXCEPTION 'Zona requerida';
  END IF;

  SELECT a.access_role,a.zone_id
  INTO v_role,v_admin_zone
  FROM public.admin_users a
  WHERE a.user_id = auth.uid()
    AND a.active = true
    AND a.allow_preview = true
  LIMIT 1;

  IF v_role IS NULL OR v_role = 'zone_monitor'
     OR (v_role <> 'super_admin' AND v_admin_zone IS DISTINCT FROM p_zone_id) THEN
    RAISE EXCEPTION 'Sin acceso al ámbito de pruebas';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.service_zones z
    WHERE z.id = p_zone_id AND z.active = true
  ) THEN
    RAISE EXCEPTION 'Zona inexistente o inactiva';
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.full_name,t.driver_id),'[]'::jsonb)
    INTO v_result
  FROM (
    SELECT
      d.id AS driver_id,
      coalesce(nullif(trim(u.full_name),''),'Conductor QA') AS full_name,
      d.zone_id,
      true AS is_qa,
      null::text AS email,
      null::text AS plan_name,
      null::uuid AS plan_id,
      null::timestamptz AS expires_at
    FROM public.driver_profiles d
    JOIN public.users u ON u.id=d.id AND u.account_status='active'
    WHERE d.zone_id=p_zone_id
      AND d.approval_status='approved'
      AND EXISTS (
        SELECT 1 FROM public.audit_test_group_members m
        WHERE m.user_id=d.id AND m.enabled=true
      )
      AND (v_search='' OR u.full_name ILIKE '%'||v_search||'%')
    ORDER BY u.full_name,d.id
    LIMIT 200
  ) t;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_preview_driver_subscription_candidates(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_preview_driver_subscription_candidates(uuid,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_preview_driver_subscription_candidates(uuid,text) TO authenticated;
