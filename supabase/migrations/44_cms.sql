-- CMS (Requirements Doc §6: "banners, home sections, FAQs, policy pages,
-- city coverage and notification templates").
-- * cms_banners: Home hero banners (image, headline, deep link, schedule).
-- * cms_pages: FAQs (one row per question: title = question, body = answer)
--   and policy/info pages (returns, terms, privacy, shipping & delivery incl.
--   city coverage). Public reads published rows; admins manage everything.
-- * cms-media: PUBLIC bucket for banner images; admin-only writes.
-- Seeded policy texts are DRAFTS for the founders/legal to review.

CREATE TABLE public.cms_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  image_path text,
  link text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cms_banners_title_check CHECK (char_length(btrim(title)) >= 2),
  CONSTRAINT cms_banners_link_check CHECK (link IS NULL OR link LIKE '/%'),
  CONSTRAINT cms_banners_window_check CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);
CREATE TRIGGER cms_banners_set_updated_at BEFORE UPDATE ON public.cms_banners
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.cms_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL,
  kind text NOT NULL,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0,
  is_published boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cms_pages_slug_unique UNIQUE (slug),
  CONSTRAINT cms_pages_slug_check CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  CONSTRAINT cms_pages_kind_check CHECK (kind IN ('faq', 'policy', 'info')),
  CONSTRAINT cms_pages_title_check CHECK (char_length(btrim(title)) >= 2)
);
CREATE TRIGGER cms_pages_set_updated_at BEFORE UPDATE ON public.cms_pages
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.cms_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cms_pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY cms_banners_public_select ON public.cms_banners
  FOR SELECT TO anon, authenticated
  USING (is_active
         AND (starts_at IS NULL OR starts_at <= now())
         AND (ends_at IS NULL OR ends_at > now()));
CREATE POLICY cms_banners_admin_all ON public.cms_banners
  FOR ALL TO authenticated USING (has_role('admin')) WITH CHECK (has_role('admin'));

CREATE POLICY cms_pages_public_select ON public.cms_pages
  FOR SELECT TO anon, authenticated USING (is_published);
CREATE POLICY cms_pages_admin_all ON public.cms_pages
  FOR ALL TO authenticated USING (has_role('admin')) WITH CHECK (has_role('admin'));

INSERT INTO storage.buckets (id, name, public)
VALUES ('cms-media', 'cms-media', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY cms_media_public_read ON storage.objects
  FOR SELECT TO anon, authenticated USING (bucket_id = 'cms-media');
CREATE POLICY cms_media_admin_insert ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'cms-media' AND has_role('admin'));
CREATE POLICY cms_media_admin_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'cms-media' AND has_role('admin'))
  WITH CHECK (bucket_id = 'cms-media' AND has_role('admin'));
CREATE POLICY cms_media_admin_delete ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'cms-media' AND has_role('admin'));

-- Seed content (DRAFT — review before launch) ----------------------------------
INSERT INTO public.cms_pages (slug, kind, title, body, sort_order) VALUES
('faq-payment', 'faq', 'How can I pay?',
 'At launch AURIVO accepts cash on delivery across Pakistan. Online payment options will be added soon.', 10),
('faq-delivery-time', 'faq', 'How long does delivery take?',
 'Ready-stock pieces usually arrive within 3–7 working days, depending on your city. Made-to-order pieces show their lead time on the product page.', 20),
('faq-returns', 'faq', 'Can I return an item?',
 'Yes — returnable items can be returned within 7 days of delivery from your order page. Custom and made-to-order pieces are not returnable unless they arrive damaged.', 30),
('faq-wholesale', 'faq', 'How do I buy wholesale?',
 'Register your business under Settings → Business account. Once verified you will see wholesale prices, tier discounts and can request quotes from sellers.', 40),
('faq-authenticity', 'faq', 'Are the pieces genuine?',
 'Sellers are verified before they can list, and every precious-metal listing shows its purity and certification where applicable. If something is not as described, open a dispute from your order.', 50),
('returns-policy', 'policy', 'Returns & refunds',
 E'DRAFT — to be confirmed by AURIVO before launch.\n\n• Returnable items can be returned within 7 days of delivery.\n• Items must be unused, with tags and certificates.\n• Made-to-order and custom pieces are not returnable unless damaged on arrival.\n• Once the seller receives the item, your refund is processed (cash-on-delivery orders are refunded manually).', 10),
('shipping-delivery', 'policy', 'Shipping & delivery',
 E'DRAFT — to be confirmed by AURIVO before launch.\n\nWe currently deliver within Pakistan. Launch cities: Lahore, Karachi, Islamabad, Rawalpindi, Faisalabad, Multan. Other cities may be served at the seller''s discretion.\n\nHigh-value orders may require phone confirmation and insured shipping.', 20),
('terms', 'policy', 'Terms of service',
 'DRAFT — AURIVO''s terms of service will be published here after legal review.', 30),
('privacy', 'policy', 'Privacy policy',
 'DRAFT — AURIVO''s privacy policy will be published here after legal review.', 40),
('about', 'info', 'About AURIVO',
 'AURIVO connects verified jewellery manufacturers and sellers with retailers, jewellers and everyday customers across Pakistan — retail and wholesale in one trusted marketplace.', 10)
ON CONFLICT (slug) DO NOTHING;
