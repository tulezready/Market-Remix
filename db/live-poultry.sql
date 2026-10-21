-- 018: live poultry, collect from the farm only.
-- The Division allows live poultry (chickens, ducks) to be sold, but only for
-- collection from the business: no delivery and no local-agent hand-off.
-- The seller ticks "Live poultry" on the product; the basket and this
-- trigger both refuse any other way of receiving it.

alter table products add column if not exists pickup_only boolean not null default false;

create or replace view public_catalogue with (security_invoker = true) as
select p.id as product_id, p.name, p.category, p.price, p.unit, p.stock, p.description, p.perishable, p.shippable,
       s.id as sme_id, s.slug as sme_slug, coalesce(s.trading_name, s.registered_name) as sme_name, s.district,
       s.primary_industry,
       (select pi.storage_path from product_images pi where pi.product_id = p.id order by pi.sort_order limit 1) as photo,
       p.badge, p.sort_key, p.created_at,
       p.subcategory,
       coalesce(p.mode, sub_mode(p.subcategory)) as mode,
       p.pickup_only
from products p join smes s on s.id = p.sme_id
where p.status = 'live'::listing_status and s.approved = true;

-- every order line: only "buy" items, fresh items stay in their district,
-- live poultry is collected from the business
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
    raise exception '% is live poultry, so it can only be collected from the business. Choose "Collect from the business".', pr.name;
  end if;
  if pr.perishable and o.fulfilment = 'delivery' and o.delivery_district is distinct from pr.district then
    raise exception '% is fresh, so it can only be delivered within % District. Choose collection, or a delivery address in % District.',
      pr.name, pr.district, pr.district;
  end if;
  return new;
end $$;
