-- La lista de avisos del panel perdió el campo «buttons» al rehacerse para incluir alertas individuales.
-- Sin él, el editor mostraba el aviso sin botones y al guardar los borraba. Se restituye.
do $m$
declare d text;
begin
  d := pg_get_functiondef('public.admin_announcement_list_v1(text,uuid,integer)'::regprocedure);
  if position('a.buttons' in d) = 0 then
    d := replace(d, 'select a.id, a.category, a.title, a.body, a.image_url, a.audience,',
                    'select a.id, a.category, a.title, a.body, a.image_url, a.buttons, a.audience,');
    d := replace(d, 'null::text as image_url,', 'null::text as image_url,' || E'\n' || '             ''[]''::jsonb as buttons,');
    if position('a.buttons' in d) = 0 or position('as buttons' in d) = 0 then
      raise exception 'No se pudo restituir buttons en admin_announcement_list_v1';
    end if;
    execute d;
  end if;
end $m$;
