-- ============================================================
-- MaketPles ENB — buy, book or ask for a quote (migration 015)
-- Each type of business works one of three ways (categories.js `mode`):
--   buy    basket and checkout, as before
--   book   the buyer requests a date and number of people
--   quote  the buyer sends a message; the business replies
-- A seller can switch a single listing (products.mode), e.g. a bulk lot
-- of copra to "quote". Requests land in `enquiries`, seen only by that
-- business and the Division. Fresh items are local only.
-- ============================================================

-- default way for each sub-category (same as categories.js)
create or replace function sub_mode(p_sub text) returns text
language sql immutable as $$
  select case p_sub
    when 'accommodation' then 'book' when 'tours' then 'book' when 'cargo_rental' then 'book'
    when 'food_service' then 'quote' when 'pmv_taxi' then 'quote'
    when 'construction' then 'quote' when 'it_office' then 'quote'
    else 'buy' end
$$;

alter table products add column if not exists mode text check (mode in ('buy','book','quote'));

create or replace view public_catalogue with (security_invoker = true) as
select p.id as product_id, p.name, p.category, p.price, p.unit, p.stock, p.description, p.perishable, p.shippable,
       s.id as sme_id, s.slug as sme_slug, coalesce(s.trading_name, s.registered_name) as sme_name, s.district,
       s.primary_industry,
       (select pi.storage_path from product_images pi where pi.product_id = p.id order by pi.sort_order limit 1) as photo,
       p.badge, p.sort_key, p.created_at,
       p.subcategory,
       coalesce(p.mode, sub_mode(p.subcategory)) as mode
from products p join smes s on s.id = p.sme_id
where p.status = 'live'::listing_status and s.approved = true;

-- every order line: only "buy" items, and fresh items stay in their district
create or replace function check_order_item() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare pr record; o record;
begin
  select p.name, p.perishable, coalesce(p.mode, sub_mode(p.subcategory)) as mode, s.district
    into pr from products p join smes s on s.id = p.sme_id where p.id = new.product_id;
  if not found then return new; end if;
  if pr.mode <> 'buy' then
    raise exception '% is booked or quoted, not bought. Please use "%" on its page.', pr.name,
      case pr.mode when 'book' then 'Request a booking' else 'Ask for a quote' end;
  end if;
  select fulfilment, delivery_district into o from orders where id = new.order_id;
  if pr.perishable and o.fulfilment = 'delivery' and o.delivery_district is distinct from pr.district then
    raise exception '% is fresh, so it can only be delivered within % District. Choose collection, or a delivery address in % District.',
      pr.name, pr.district, pr.district;
  end if;
  return new;
end $$;
drop trigger if exists trg_check_order_item on order_items;
create trigger trg_check_order_item before insert on order_items for each row execute function check_order_item();

-- requests: bookings and quotes
create sequence if not exists enquiry_seq start 1001;
create table if not exists enquiries (
  id          uuid primary key default gen_random_uuid(),
  reference   text unique not null default ('ENB-R' || nextval('enquiry_seq')),
  sme_id      uuid not null references smes(id) on delete cascade,
  product_id  uuid references products(id) on delete set null,
  product_name text,
  kind        text not null check (kind in ('booking','quote')),
  buyer_name  text not null,
  buyer_phone text not null,
  buyer_email text,
  date_from   date,
  date_to     date,
  people      int check (people between 1 and 500),
  message     text check (length(message) <= 1000),
  status      text not null default 'new' check (status in ('new','contacted','done','cancelled')),
  seller_note text check (length(seller_note) <= 500),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_enquiries_sme on enquiries(sme_id, created_at desc);
alter table enquiries enable row level security;
drop policy if exists enquiries_read on enquiries;
create policy enquiries_read on enquiries for select using (owns_sme(sme_id) or is_division());
drop policy if exists enquiries_update on enquiries;
create policy enquiries_update on enquiries for update using (owns_sme(sme_id) or is_division()) with check (owns_sme(sme_id) or is_division());
revoke all on enquiries from anon, authenticated;
grant select on enquiries to authenticated;
grant update (status, seller_note, updated_at) on enquiries to authenticated;

-- the public sends a request through this function only
create or replace function submit_enquiry(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  pr record; v_kind text; v_ref text;
  v_name text := btrim(coalesce(p->>'buyer_name',''));
  v_phone text := btrim(coalesce(p->>'buyer_phone',''));
  v_from date; v_to date; v_people int;
begin
  select p2.id, p2.name, p2.sme_id, coalesce(p2.mode, sub_mode(p2.subcategory)) as mode into pr
    from products p2 join smes s on s.id = p2.sme_id
   where p2.id = (p->>'product_id')::uuid and p2.status = 'live' and s.approved;
  if not found then raise exception 'This listing is not available.'; end if;
  v_kind := case when pr.mode = 'book' then 'booking' else 'quote' end;
  if length(v_name) < 2 or length(v_name) > 100 then raise exception 'Please enter your name.'; end if;
  if v_phone !~ '^\+?[0-9 ]{7,20}$' then raise exception 'Please enter a valid mobile number.'; end if;
  if length(coalesce(p->>'message','')) > 1000 then raise exception 'Please keep the message under 1,000 characters.'; end if;
  if (select count(*) from enquiries where buyer_phone = v_phone and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Too many requests from this number. Please try again later.';
  end if;
  if v_kind = 'booking' then
    begin
      v_from := nullif(p->>'date_from','')::date; v_to := nullif(p->>'date_to','')::date;
      v_people := nullif(p->>'people','')::int;
    exception when others then raise exception 'Please check the dates and number of people.'; end;
    if v_from is null then raise exception 'Please choose a date.'; end if;
    if v_from < current_date then raise exception 'Please choose a date from today on.'; end if;
    if v_to is not null and v_to < v_from then raise exception 'The end date is before the start date.'; end if;
    if v_people is not null and (v_people < 1 or v_people > 500) then raise exception 'Please check the number of people.'; end if;
  elsif length(btrim(coalesce(p->>'message',''))) < 3 then
    raise exception 'Please say what you need.';
  end if;
  insert into enquiries (sme_id, product_id, product_name, kind, buyer_name, buyer_phone, buyer_email,
                         date_from, date_to, people, message)
  values (pr.sme_id, pr.id, pr.name, v_kind, v_name, v_phone, nullif(btrim(coalesce(p->>'buyer_email','')), ''),
          v_from, v_to, v_people, nullif(btrim(coalesce(p->>'message','')), ''))
  returning reference into v_ref;
  return jsonb_build_object('reference', v_ref, 'kind', v_kind);
end $$;
revoke all on function submit_enquiry(jsonb) from public;
grant execute on function submit_enquiry(jsonb) to anon, authenticated;
