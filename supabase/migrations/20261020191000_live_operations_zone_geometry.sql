-- Read-only map geometry for the logged-in administrator's effective zone.
-- Shared coverage is read from service_zones; this never modifies geography.
CREATE OR REPLACE FUNCTION public.admin_live_zone_coverage_get(
  p_zone_id uuid,
  p_channel text
) RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_zone_id uuid;
  v_mode text;
  v_polygon jsonb;
BEGIN
  IF auth.uid() IS NULL
     OR p_channel NOT IN ('preview', 'production')
     OR NOT coalesce(public.admin_environment_allowed(p_channel), false) THEN
    RAISE EXCEPTION 'No autorizado para la cobertura operativa';
  END IF;

  -- Operators can inspect geometry only when Live Operations is authorized.
  PERFORM public.admin_operator_assert_module('live_operations');
  v_zone_id := public.admin_effective_zone_id(p_zone_id);

  SELECT z.coverage_mode INTO v_mode
  FROM public.service_zones z
  WHERE z.id = v_zone_id AND z.active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Zona operativa no encontrada';
  END IF;

  IF v_mode = 'polygon' THEN
    SELECT p.polygon INTO v_polygon
    FROM public.service_zone_polygons p
    WHERE p.zone_id = v_zone_id AND p.active = true
    ORDER BY p.updated_at DESC, p.id DESC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'zone_id', v_zone_id,
    'coverage_mode', v_mode,
    'polygon', CASE WHEN v_mode = 'polygon'
               THEN coalesce(v_polygon, '[]'::jsonb)
               ELSE '[]'::jsonb END
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_live_zone_coverage_get(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_live_zone_coverage_get(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_live_zone_coverage_get(uuid, text) TO authenticated;
