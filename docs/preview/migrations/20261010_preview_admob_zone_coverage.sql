-- Applied ONLY to Express Preview (xbphilqezmwfjfpdbwad). Never to Production.
-- Restores admin RPC parity for zone coverage and AdMob QA controls, without
-- live advertisement IDs or calls to external systems.
CREATE OR REPLACE FUNCTION public.admin_zone_coverage_get(p_zone_id uuid, p_channel text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_zone public.service_zones%rowtype; v_polygon jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() OR p_channel <> 'preview'
    OR NOT public.admin_environment_allowed('preview') THEN
   RAISE EXCEPTION 'No autorizado para ver la cobertura de Preview';
 END IF;
 SELECT * INTO v_zone FROM public.service_zones WHERE id=p_zone_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Zona no encontrada'; END IF;
 SELECT to_jsonb(p) INTO v_polygon
   FROM public.service_zone_polygons p
   WHERE p.zone_id=p_zone_id AND p.active=true
   ORDER BY p.updated_at DESC,p.id DESC LIMIT 1;
 RETURN jsonb_build_object(
   'zone_id',v_zone.id,'coverage_mode',v_zone.coverage_mode,
   'center_latitude',v_zone.center_latitude,
   'center_longitude',v_zone.center_longitude,
   'radius_km',v_zone.radius_km,
   'polygon',coalesce(v_polygon->'polygon','[]'::jsonb),
   'polygon_id',v_polygon->>'id');
END $$;

CREATE OR REPLACE FUNCTION public.admin_admob_settings_get(p_channel text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_settings public.app_settings%rowtype;
BEGIN
 IF auth.uid() IS NULL OR p_channel <> 'preview' OR NOT public.is_admin()
    OR NOT public.admin_environment_allowed('preview') THEN
   RAISE EXCEPTION 'Sin permiso para consultar anuncios Preview';
 END IF;
 SELECT * INTO v_settings FROM public.app_settings WHERE id = true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Configuración Preview no disponible'; END IF;
 RETURN jsonb_build_object(
   'channel','preview',
   'enabled',v_settings.ads_passenger_preview_enabled,
   'home_enabled',v_settings.ads_passenger_preview_home_enabled,
   'trip_enabled',v_settings.ads_passenger_preview_trip_enabled,
   'admob_android_app_id',null,
   'admob_passenger_banner_unit_id',null,
   'admob_publisher_id',null,
   'updated_at',v_settings.updated_at);
END $$;

CREATE OR REPLACE FUNCTION public.admin_admob_settings_update(
 p_channel text, p_enabled boolean, p_home_enabled boolean, p_trip_enabled boolean,
 p_android_app_id text DEFAULT NULL, p_banner_unit_id text DEFAULT NULL,
 p_publisher_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
 IF auth.uid() IS NULL OR p_channel <> 'preview' OR NOT public.is_admin()
    OR NOT public.admin_environment_allowed('preview') THEN
   RAISE EXCEPTION 'Sin permiso para cambiar anuncios Preview';
 END IF;
 IF p_enabled IS NULL OR p_home_enabled IS NULL OR p_trip_enabled IS NULL THEN
   RAISE EXCEPTION 'Los interruptores deben ser booleanos válidos';
 END IF;
 IF nullif(trim(coalesce(p_android_app_id,'')),'') IS NOT NULL OR
    nullif(trim(coalesce(p_banner_unit_id,'')),'') IS NOT NULL OR
    nullif(trim(coalesce(p_publisher_id,'')),'') IS NOT NULL THEN
   RAISE EXCEPTION 'Los ID reales de AdMob no están permitidos en Preview';
 END IF;
 UPDATE public.app_settings SET
   ads_passenger_preview_enabled=p_enabled,
   ads_passenger_preview_home_enabled=p_home_enabled,
   ads_passenger_preview_trip_enabled=p_trip_enabled,
   updated_at=now() WHERE id=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Configuración Preview no disponible'; END IF;
 RETURN public.admin_admob_settings_get('preview');
END $$;

REVOKE ALL ON FUNCTION public.admin_zone_coverage_get(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_admob_settings_get(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_admob_settings_update(text,boolean,boolean,boolean,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_zone_coverage_get(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_admob_settings_get(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_admob_settings_update(text,boolean,boolean,boolean,text,text,text) TO authenticated;
