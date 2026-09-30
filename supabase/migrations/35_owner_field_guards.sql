-- Owner-writable rows must not let owners change platform-controlled fields.
-- RLS allows sellers to update their own products / store and quotes, but the
-- following columns are platform-managed:
--   products:        featured, rating_average, rating_count
--   seller_profiles: commission_rate, rating_average, rating_count
--   quotes:          only the buyer's accept_quote RPC (or an admin) may set
--                    'accepted'; accepted/rejected quotes are final for sellers.
-- Admins and server-side jobs (auth.uid() is null) are unaffected. Platform
-- code that updates these fields on behalf of a non-admin user (e.g. a rating
-- aggregation trigger) must set the transaction-local flag
-- `set_config('aurivo.system_write', 'on', true)` first.

CREATE OR REPLACE FUNCTION public.enforce_product_owner_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null or has_role('admin')
     or current_setting('aurivo.system_write', true) = 'on' then
    return NEW;
  end if;
  if TG_OP = 'INSERT' then
    NEW.featured := false;
    NEW.rating_average := 0;
    NEW.rating_count := 0;
  else
    NEW.featured := OLD.featured;
    NEW.rating_average := OLD.rating_average;
    NEW.rating_count := OLD.rating_count;
  end if;
  return NEW;
end;
$function$;

DROP TRIGGER IF EXISTS products_owner_fields_guard ON public.products;
CREATE TRIGGER products_owner_fields_guard
  BEFORE INSERT OR UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.enforce_product_owner_fields();

CREATE OR REPLACE FUNCTION public.enforce_seller_owner_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null or has_role('admin')
     or current_setting('aurivo.system_write', true) = 'on' then
    return NEW;
  end if;
  if TG_OP = 'INSERT' then
    NEW.commission_rate := null;
    NEW.rating_average := 0;
    NEW.rating_count := 0;
  else
    NEW.commission_rate := OLD.commission_rate;
    NEW.rating_average := OLD.rating_average;
    NEW.rating_count := OLD.rating_count;
  end if;
  return NEW;
end;
$function$;

DROP TRIGGER IF EXISTS seller_profiles_owner_fields_guard ON public.seller_profiles;
CREATE TRIGGER seller_profiles_owner_fields_guard
  BEFORE INSERT OR UPDATE ON public.seller_profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_seller_owner_fields();

CREATE OR REPLACE FUNCTION public.enforce_quote_status_rules()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_is_buyer boolean;
begin
  if NEW.status is not distinct from OLD.status
     or auth.uid() is null or has_role('admin') then
    return NEW;
  end if;
  select r.buyer_profile_id = current_profile_id() into v_is_buyer
  from public.rfqs r where r.id = NEW.rfq_id;
  -- Buyers have no UPDATE policy on quotes, so a buyer-driven change can only
  -- come from accept_quote (SECURITY DEFINER).
  if coalesce(v_is_buyer, false) then
    return NEW;
  end if;
  if NEW.status = 'accepted' then
    raise exception 'Only the buyer can accept a quote.' using errcode = '42501';
  end if;
  if OLD.status in ('accepted', 'rejected') then
    raise exception 'This quote is final and can no longer be changed.'
      using errcode = '42501';
  end if;
  return NEW;
end;
$function$;

DROP TRIGGER IF EXISTS quotes_status_guard ON public.quotes;
CREATE TRIGGER quotes_status_guard
  BEFORE UPDATE ON public.quotes
  FOR EACH ROW EXECUTE FUNCTION public.enforce_quote_status_rules();
