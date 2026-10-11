-- Shared Express Supabase (Preview and Production): preserve explicit Preview
-- notifications if a producer does not set app.runtime_channel.
-- Security: an explicit Preview notification can only target an active QA user.
-- Production logic remains backwards compatible (including legacy QA accounts).
-- Back up current definition before applying. Revert by restoring pg_get_functiondef.
CREATE OR REPLACE FUNCTION public.notification_runtime_channel()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_context text := nullif(lower(trim(current_setting('app.runtime_channel', true))), '');
  v_requested text;
  v_existing text;
  v_related text;
  v_id uuid;
BEGIN
  NEW.metadata := coalesce(NEW.metadata, '{}'::jsonb);
  v_requested := nullif(lower(trim(NEW.metadata->>'channel')), '');
  v_existing := nullif(lower(trim(NEW.channel)), '');

  IF v_context NOT IN ('preview','production') THEN v_context := null; END IF;
  IF v_requested NOT IN ('preview','production') THEN v_requested := null; END IF;
  IF v_existing NOT IN ('preview','production') THEN v_existing := null; END IF;

  IF NEW.metadata ? 'ride_request_id' THEN
    BEGIN
      v_id := (NEW.metadata->>'ride_request_id')::uuid;
      SELECT r.channel INTO v_related FROM public.ride_requests r WHERE r.id=v_id;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'ID de solicitud inválido en notificación';
    END;
  END IF;

  IF NEW.metadata ? 'trip_id' THEN
    BEGIN
      v_id := (NEW.metadata->>'trip_id')::uuid;
      IF EXISTS (SELECT 1 FROM public.trips t WHERE t.id=v_id AND v_related IS NOT NULL AND t.channel<>v_related) THEN
        RAISE EXCEPTION 'Referencias de notificación cruzan canales';
      END IF;
      SELECT coalesce(v_related, (SELECT t.channel FROM public.trips t WHERE t.id=v_id)) INTO v_related;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'ID de viaje inválido en notificación';
    END;
  END IF;

  IF NEW.metadata ? 'delivery_id' THEN
    BEGIN
      v_id := (NEW.metadata->>'delivery_id')::uuid;
      IF EXISTS (SELECT 1 FROM public.delivery_requests d WHERE d.id=v_id AND v_related IS NOT NULL AND d.channel<>v_related) THEN
        RAISE EXCEPTION 'Referencias de notificación cruzan canales';
      END IF;
      SELECT coalesce(v_related, (SELECT d.channel FROM public.delivery_requests d WHERE d.id=v_id)) INTO v_related;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'ID de delivery inválido en notificación';
    END;
  END IF;

  IF v_related IS NOT NULL AND v_context IS NOT NULL AND v_related<>v_context THEN
    RAISE EXCEPTION 'Contexto de notificación incompatible con operación';
  END IF;
  IF v_related IS NOT NULL AND v_requested IS NOT NULL AND v_related<>v_requested THEN
    RAISE EXCEPTION 'Canal solicitado incompatible con operación';
  END IF;
  IF v_context IS NOT NULL AND v_requested IS NOT NULL AND v_context<>v_requested THEN
    RAISE EXCEPTION 'Canal solicitado incompatible con contexto';
  END IF;
  IF v_existing='preview' AND (v_related='production' OR v_context='production') THEN
    RAISE EXCEPTION 'Notificación Preview no puede ir a Producción';
  END IF;

  -- Explicit Preview wins over the column's default 'production', but a
  -- referenced operation and its transaction context are authoritative.
  NEW.channel := coalesce(v_related, v_context, v_requested, v_existing, 'production');
  IF TG_OP='UPDATE' AND NEW.channel IS DISTINCT FROM OLD.channel THEN
    RAISE EXCEPTION 'No se puede cambiar el canal de una notificación existente';
  END IF;
  IF NEW.channel='preview' AND NOT public.is_active_audit_user(NEW.user_id) THEN
    RAISE EXCEPTION 'No se puede notificar por Preview a un usuario real';
  END IF;
  NEW.metadata := NEW.metadata || jsonb_build_object('channel',NEW.channel);
  RETURN NEW;
END;
$function$;
