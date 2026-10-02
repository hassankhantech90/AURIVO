-- Urdu-ready data model (Requirements Doc §9: "English at launch; content and
-- data model must support Urdu and additional languages later").
-- One generic column per content table:
--   translations = { "<lang>": { "<field>": "<text>", ... }, ... }
-- e.g. products.translations = {"ur": {"title": "…", "description": "…"}}.
-- English stays in the existing columns; the app shows a translation when the
-- chosen language has one and falls back to English otherwise. Adding a new
-- language needs no schema change.
DO $$
declare t text;
begin
  foreach t in array array['products', 'categories', 'brands', 'cms_pages', 'cms_banners']
  loop
    execute format(
      'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS translations jsonb NOT NULL DEFAULT %L::jsonb',
      t, '{}');
    execute format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (jsonb_typeof(translations) = %L)',
      t, t || '_translations_object', 'object');
  end loop;
end $$;

-- Seed Urdu for the Help centre FAQs as an example (review before launch).
UPDATE public.cms_pages SET translations = jsonb_build_object('ur', jsonb_build_object(
  'title', 'میں ادائیگی کیسے کر سکتا ہوں؟',
  'body', 'آغاز میں AURIVO پورے پاکستان میں کیش آن ڈیلیوری قبول کرتا ہے۔ آن لائن ادائیگی کے طریقے جلد شامل کیے جائیں گے۔'))
WHERE slug = 'faq-payment';
UPDATE public.cms_pages SET translations = jsonb_build_object('ur', jsonb_build_object(
  'title', 'کیا میں کوئی چیز واپس کر سکتا ہوں؟',
  'body', 'جی ہاں — قابلِ واپسی اشیاء ڈیلیوری کے 7 دن کے اندر آپ کے آرڈر صفحے سے واپس کی جا سکتی ہیں۔ آرڈر پر بنائی گئی اشیاء واپس نہیں ہوتیں جب تک وہ خراب حالت میں نہ پہنچیں۔'))
WHERE slug = 'faq-returns';
