-- Only an admin may set/change a business profile's verification_status; a
-- buyer's own insert/update is forced to leave it at the server's control
-- (mirrors enforce_seller_verification_moderation).
CREATE OR REPLACE FUNCTION public.enforce_business_verification_moderation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null or has_role('admin') then
    return NEW;
  end if;
  if TG_OP = 'INSERT' then
    if NEW.verification_status is distinct from 'pending' then
      raise exception 'Only an administrator can set business verification status'
        using errcode = '42501';
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.verification_status is distinct from OLD.verification_status then
      raise exception 'Only an administrator can change business verification status'
        using errcode = '42501';
    end if;
  end if;
  return NEW;
end;
$function$;

DROP TRIGGER IF EXISTS enforce_business_verification_moderation ON public.business_profiles;
CREATE TRIGGER enforce_business_verification_moderation
  BEFORE INSERT OR UPDATE ON public.business_profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_business_verification_moderation();
