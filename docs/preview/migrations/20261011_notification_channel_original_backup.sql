-- Exact original body before the notification isolation fix, 2026-10-11
CREATE OR REPLACE FUNCTION public.notification_runtime_channel()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_channel text:=nullif(current_setting('app.runtime_channel',true),'');
  v_id uuid;
begin
  if v_channel not in ('preview','production') then
    v_channel:=null;
  end if;

  if v_channel is null and new.metadata ? 'ride_request_id' then
    begin
      v_id:=(new.metadata->>'ride_request_id')::uuid;
      select channel into v_channel from public.ride_requests where id=v_id;
    exception when others then null;
    end;
  end if;

  if v_channel is null and new.metadata ? 'trip_id' then
    begin
      v_id:=(new.metadata->>'trip_id')::uuid;
      select channel into v_channel from public.trips where id=v_id;
    exception when others then null;
    end;
  end if;

  if v_channel is null and new.metadata ? 'delivery_id' then
    begin
      v_id:=(new.metadata->>'delivery_id')::uuid;
      select channel into v_channel from public.delivery_requests where id=v_id;
    exception when others then null;
    end;
  end if;

  new.channel:=public.normalize_runtime_channel(v_channel);
  new.metadata:=coalesce(new.metadata,'{}'::jsonb)
    || jsonb_build_object('channel',new.channel);
  return new;
end;
$function$;
