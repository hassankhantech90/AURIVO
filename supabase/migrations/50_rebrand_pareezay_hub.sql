-- Rebrand: AURIVO -> Pareezay.Hub in user-facing database content.
-- (Internal identifiers — Supabase project, Dart package, app ID — are
-- unchanged until store-release prep.)

-- Seeded Help-centre / policy content, including translations.
UPDATE public.cms_pages
SET title = replace(title, 'AURIVO', 'Pareezay.Hub'),
    body = replace(body, 'AURIVO', 'Pareezay.Hub'),
    translations = replace(translations::text, 'AURIVO', 'Pareezay.Hub')::jsonb
WHERE title LIKE '%AURIVO%' OR body LIKE '%AURIVO%'
   OR translations::text LIKE '%AURIVO%';

UPDATE public.cms_banners
SET title = replace(title, 'AURIVO', 'Pareezay.Hub'),
    subtitle = replace(subtitle, 'AURIVO', 'Pareezay.Hub')
WHERE title LIKE '%AURIVO%' OR subtitle LIKE '%AURIVO%';

-- Server messages: rewrite the brand inside function bodies (must match).
DO $$
declare r record; v_def text;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and pg_get_functiondef(p.oid) like '%AURIVO%'
  loop
    v_def := pg_get_functiondef(r.fn);
    execute replace(v_def, 'AURIVO', 'Pareezay.Hub');
  end loop;
  if exists (select 1 from pg_proc p
             where p.pronamespace = 'public'::regnamespace
               and pg_get_functiondef(p.oid) like '%AURIVO%') then
    raise exception 'AURIVO still present in a function body';
  end if;
end $$;
