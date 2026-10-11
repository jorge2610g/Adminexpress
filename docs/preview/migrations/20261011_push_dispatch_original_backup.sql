-- Previous dispatch_push_notification() body; restore on regression.
CREATE OR REPLACE FUNCTION public.dispatch_push_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'net'
AS $function$
declare
  v_secret text;
begin
  select webhook_secret into v_secret
  from public.push_server_config where id = true;
  if v_secret is null then return new; end if;

  perform net.http_post(
    url := 'https://zgpijrznvaskgcmauwxx.supabase.co/functions/v1/express-push-dispatch',
    body := jsonb_build_object(
      'notification_id', new.id,
      'user_id', new.user_id,
      'title', new.title,
      'body', new.body,
      'type', new.type,
      'metadata', coalesce(new.metadata,'{}'::jsonb)
    ),
    params := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-express-push-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
  return new;
end;
$function$;
