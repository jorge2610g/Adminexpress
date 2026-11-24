-- Botones de enlace en los avisos (hasta 3, solo https).
alter table public.announcements add column if not exists buttons jsonb not null default '[]'::jsonb;

create or replace function public.announcement_clean_buttons(p_buttons jsonb)
returns jsonb language plpgsql immutable set search_path to 'public' as $$
declare r jsonb := '[]'::jsonb; b jsonb; v_label text; v_url text;
begin
  if p_buttons is null or jsonb_typeof(p_buttons) <> 'array' then return r; end if;
  if jsonb_array_length(p_buttons) > 3 then raise exception 'Máximo 3 botones por aviso'; end if;
  for b in select * from jsonb_array_elements(p_buttons) loop
    v_label := trim(coalesce(b->>'label', ''));
    v_url := trim(coalesce(b->>'url', ''));
    if v_label = '' and v_url = '' then continue; end if;
    if char_length(v_label) < 1 or char_length(v_label) > 30 then raise exception 'El texto del botón debe tener entre 1 y 30 caracteres'; end if;
    if v_url !~* '^https://[^\s]+$' or char_length(v_url) > 500 then raise exception 'El enlace del botón debe empezar con https://'; end if;
    r := r || jsonb_build_array(jsonb_build_object('label', v_label, 'url', v_url));
  end loop;
  return r;
end $$;

do $m$
declare d text; old regprocedure := 'public.admin_announcement_save_v1(text,uuid,text,text,text,text,text,uuid,uuid,timestamptz,timestamptz,text)'::regprocedure;
begin
  -- guardar
  d := pg_get_functiondef(old);
  d := replace(d, 'p_status text DEFAULT ''published''::text)', 'p_status text DEFAULT ''published''::text, p_buttons jsonb DEFAULT NULL::jsonb)');
  d := replace(d, 'status, publish_at, expires_at, created_by)', 'status, publish_at, expires_at, created_by, buttons)');
  d := replace(d, 'p_status, coalesce(p_publish_at, now()), p_expires_at, auth.uid())', 'p_status, coalesce(p_publish_at, now()), p_expires_at, auth.uid(), public.announcement_clean_buttons(p_buttons))');
  d := replace(d, 'expires_at = p_expires_at, updated_at = now()', 'expires_at = p_expires_at, buttons = public.announcement_clean_buttons(p_buttons), updated_at = now()');
  if position('p_buttons jsonb' in d) = 0 or position('buttons = public.announcement_clean_buttons' in d) = 0
     or position('auth.uid(), public.announcement_clean_buttons' in d) = 0 or position('created_by, buttons)' in d) = 0 then
    raise exception 'patch guardar no aplicado';
  end if;
  execute 'drop function public.admin_announcement_save_v1(text,uuid,text,text,text,text,text,uuid,uuid,timestamptz,timestamptz,text)';
  execute d;
  execute 'revoke all on function public.admin_announcement_save_v1(text,uuid,text,text,text,text,text,uuid,uuid,timestamptz,timestamptz,text,jsonb) from public, anon';
  execute 'grant execute on function public.admin_announcement_save_v1(text,uuid,text,text,text,text,text,uuid,uuid,timestamptz,timestamptz,text,jsonb) to authenticated';

  -- listado admin
  d := pg_get_functiondef('public.admin_announcement_list_v1(text,uuid,integer)'::regprocedure);
  d := replace(d, 'a.image_url, a.audience', 'a.image_url, a.buttons, a.audience');
  if position('a.buttons' in d) = 0 then raise exception 'patch lista no aplicado'; end if;
  execute d;

  -- lista del usuario
  d := pg_get_functiondef('public.my_announcements_v1(text,integer)'::regprocedure);
  d := replace(d, '''image_url'', a.image_url,', '''image_url'', a.image_url, ''buttons'', a.buttons,');
  d := replace(d, '''image_url'', null,', '''image_url'', null, ''buttons'', ''[]''::jsonb,');
  if position('a.buttons' in d) = 0 then raise exception 'patch my no aplicado'; end if;
  execute d;
end $m$;
