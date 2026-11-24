-- La función de envío push lee metadata.channel para elegir el token nativo (preview/production).
-- Añade 'channel' junto a 'environment' en los datos de la notificación de las dos nuevas rutas.
do $m$
declare d text;
begin
  d := pg_get_functiondef('public.admin_send_push_v1(text,text,text,text,text,uuid,uuid,uuid)'::regprocedure);
  d := replace(d, '''campaign_id'', v_campaign, ''environment'', v_channel)', '''campaign_id'', v_campaign, ''environment'', v_channel, ''channel'', v_channel)');
  if position('''channel'', v_channel)' in d) = 0 then raise exception 'patch push no aplicado'; end if;
  execute d;

  d := pg_get_functiondef('public.admin_support_ticket_reply_v1(text,uuid,text)'::regprocedure);
  d := replace(d, 'jsonb_build_object(''environment'', v_channel), v_channel);', 'jsonb_build_object(''environment'', v_channel, ''channel'', v_channel), v_channel);');
  if position('''channel'', v_channel)' in d) = 0 then raise exception 'patch reply no aplicado'; end if;
  execute d;
end $m$;
