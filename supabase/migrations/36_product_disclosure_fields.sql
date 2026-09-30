-- Product disclosure fields (Requirements Doc §3):
--   "Every precious-metal product must show weight, purity/karat,
--    certification details where applicable, making charges, return terms…"
--   "Made-to-order items must show lead time, advance-payment policy and
--    whether cancellation/return is allowed before checkout."
-- Weight lives on variants and purity/material already exist on products.
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS certification text,
  ADD COLUMN IF NOT EXISTS making_charges numeric(12,2),
  ADD COLUMN IF NOT EXISTS dimensions text,
  ADD COLUMN IF NOT EXISTS is_returnable boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_made_to_order boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS lead_time_days integer,
  ADD COLUMN IF NOT EXISTS advance_payment_percent integer;

ALTER TABLE public.products
  ADD CONSTRAINT products_making_charges_nonneg
    CHECK (making_charges IS NULL OR making_charges >= 0),
  ADD CONSTRAINT products_lead_time_days_positive
    CHECK (lead_time_days IS NULL OR lead_time_days > 0),
  ADD CONSTRAINT products_advance_payment_percent_range
    CHECK (advance_payment_percent IS NULL
           OR advance_payment_percent BETWEEN 0 AND 100),
  ADD CONSTRAINT products_made_to_order_needs_lead_time
    CHECK (NOT is_made_to_order OR lead_time_days IS NOT NULL);
