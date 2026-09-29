-- Wholesale is B2B: only a buyer with a verified business profile (or an admin)
-- may create an RFQ. This is the authoritative gate behind the client checks.
CREATE OR REPLACE FUNCTION public.enforce_rfq_verified_business()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null or has_role('admin') then
    return NEW;
  end if;
  if not exists (
    select 1 from public.business_profiles b
    where b.profile_id = NEW.buyer_profile_id
      and b.verification_status = 'verified'
      and b.deleted_at is null
  ) then
    raise exception 'A verified business is required to request wholesale quotes.';
  end if;
  return NEW;
end;
$function$;

DROP TRIGGER IF EXISTS enforce_rfq_verified_business ON public.rfqs;
CREATE TRIGGER enforce_rfq_verified_business
  BEFORE INSERT ON public.rfqs
  FOR EACH ROW EXECUTE FUNCTION public.enforce_rfq_verified_business();
