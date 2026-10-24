-- 020: kerosene, like live poultry, is sold for collection only.
-- The rules allow kerosene (sealed containers, collected from the business);
-- the Division ticks "Collect only" on the listing. The order check's
-- message no longer assumes every collect-only item is live poultry.

create or replace function check_order_item() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare pr record; o record;
begin
  select p.name, p.perishable, p.pickup_only, coalesce(p.mode, sub_mode(p.subcategory)) as mode, s.district
    into pr from products p join smes s on s.id = p.sme_id where p.id = new.product_id;
  if not found then return new; end if;
  if pr.mode <> 'buy' then
    raise exception '% is booked or quoted, not bought. Please use "%" on its page.', pr.name,
      case pr.mode when 'book' then 'Request a booking' else 'Ask for a quote' end;
  end if;
  select fulfilment, delivery_district into o from orders where id = new.order_id;
  if pr.pickup_only and o.fulfilment <> 'sme_pickup' then
    raise exception '% can only be collected from the business. Choose "Collect from the business".', pr.name;
  end if;
  if pr.perishable and o.fulfilment = 'delivery' and o.delivery_district is distinct from pr.district then
    raise exception '% is fresh, so it can only be delivered within % District. Choose collection, or a delivery address in % District.',
      pr.name, pr.district, pr.district;
  end if;
  return new;
end $$;
