-- Tell the seller when a buyer accepts their quote (accept_quote flips
-- quotes.status 'sent' -> 'accepted'). The generic "New order" notification
-- still fires from order_items; this one ties the order back to the quote.
CREATE OR REPLACE FUNCTION public.notify_quote_accepted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_seller uuid;
begin
  if NEW.status is not distinct from OLD.status or NEW.status <> 'accepted' then
    return NEW;
  end if;
  select profile_id into v_seller from public.seller_profiles
    where id = NEW.seller_profile_id and deleted_at is null;
  if v_seller is null then return NEW; end if;
  insert into public.notifications(profile_id, type, title, body, data)
  select v_seller, 'seller_event', 'Quote accepted',
         'A buyer accepted your quote and placed a wholesale order.',
         jsonb_build_object('event','quote_accepted','quote_id',NEW.id::text,
           'rfq_id',NEW.rfq_id::text,
           'route','/seller-studio/rfqs/'||NEW.rfq_id::text)
  where not exists (select 1 from public.notifications n
                    where n.profile_id = v_seller and n.type='seller_event'
                      and n.data->>'event' = 'quote_accepted'
                      and n.data->>'quote_id' = NEW.id::text);
  return NEW;
end $function$;

DROP TRIGGER IF EXISTS quotes_notify_seller_accepted ON public.quotes;
CREATE TRIGGER quotes_notify_seller_accepted
  AFTER UPDATE OF status ON public.quotes
  FOR EACH ROW EXECUTE FUNCTION public.notify_quote_accepted();
