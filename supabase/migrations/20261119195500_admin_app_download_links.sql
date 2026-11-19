-- QR único de Express: destinos administrables de Android, iOS y web.
-- Configuración canónica compartida por administradores Preview y Producción.
CREATE TABLE IF NOT EXISTS public.app_download_links (
  platform text PRIMARY KEY CHECK (platform IN ('android', 'ios', 'web')),
  url text NOT NULL DEFAULT '',
  enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT app_download_links_https CHECK (
    url = '' OR (length(url) <= 2048 AND url ~* '^https://[^[:space:]]+$')
  )
);
ALTER TABLE public.app_download_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_download_links FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.app_download_links TO anon, authenticated;
DROP POLICY IF EXISTS app_download_links_public_read ON public.app_download_links;
CREATE POLICY app_download_links_public_read ON public.app_download_links
  FOR SELECT TO anon, authenticated USING (true);

INSERT INTO public.app_download_links (platform,url,enabled)
VALUES
  ('android','https://play.google.com/store/apps/details?id=com.express.usuario1',true),
  ('ios','',false),
  ('web','https://expressviajes.online/',true)
ON CONFLICT (platform) DO NOTHING;

CREATE OR REPLACE FUNCTION public.admin_app_download_link_update(
  p_platform text, p_url text, p_enabled boolean
)
RETURNS public.app_download_links
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_access jsonb;
  v_url text := btrim(coalesce(p_url, ''));
  v_row public.app_download_links%ROWTYPE;
BEGIN
  v_access := public.admin_access_context();
  IF v_access->>'role' IS DISTINCT FROM 'super_admin'
     OR v_access->>'allowed' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Solo el superadministrador puede modificar enlaces de descarga.'
      USING ERRCODE = '42501';
  END IF;
  IF p_platform IS NULL OR p_platform NOT IN ('android','ios','web') THEN
    RAISE EXCEPTION 'Plataforma no permitida.';
  END IF;
  IF (v_url <> '' AND (length(v_url) > 2048
                     OR v_url !~* '^https://[^[:space:]]+$'))
     OR (coalesce(p_enabled,false) AND v_url = '') THEN
    RAISE EXCEPTION 'Ingresa una URL HTTPS válida antes de activar la plataforma.';
  END IF;

  UPDATE public.app_download_links
     SET url = v_url,
         enabled = coalesce(p_enabled,false),
         updated_at = now(),
         updated_by = auth.uid()
   WHERE platform = p_platform
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No existe la plataforma solicitada.';
  END IF;
  RETURN v_row;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_app_download_link_update(text,text,boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_app_download_link_update(text,text,boolean)
  TO authenticated;
