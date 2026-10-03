-- ============================================================
--  MaketPles ENB — Security fixes, ordering, payouts
--  Run THIRD: after db/schema.sql and db/public-submissions.sql.
-- ------------------------------------------------------------
--  This is the combined, final form of migrations 003–007 that
--  were applied to the live project (maketples-enb, Sydney) on
--  3 October 2026. Safe to re-run.
--
--  What it fixes / adds:
--   1. Contact, tax and bank details move to sme_private.
--      Row level security filters ROWS, not columns: on the public
--      smes table anyone could read an approved business's bank
--      account and phone number.
--   2. Orders can only be created by place_order(), which prices
--      everything on the server. Before, the browser could insert
--      orders and order items with any price and any fee rate.
--   3. submit_application(): the register form's insert-then-select
--      was refused because the public cannot read applications.
--   4. platform_settings, payouts with two-person approval, and
--      seller_balances (held / available / paid out).
--   5. Function hardening flagged by the Supabase advisor.
-- ============================================================


-- ============================================================
-- 1. PRIVATE BUSINESS DETAILS
-- ============================================================
create table if not exists sme_private (
  sme_id            uuid primary key references smes(id) on delete cascade,
  contact_name      text,
  phone             text,
  email             text,
  ipa_number        text,
  tin               text,
  bank_name         text,
  account_name      text,
  account_number    text,
  bank_verified     boolean not null default false,
  bank_verified_at  timestamptz,
  bank_verified_by  uuid references profiles(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
comment on table sme_private is 'Private details for each business. Readable only by its owner and the Division.';
comment on column sme_private.bank_verified is
  'Set by the Division after confirming the account by phone. Any change to the bank details resets it.';

alter table sme_private enable row level security;
drop policy if exists sme_private_owner_read on sme_private;
create policy sme_private_owner_read on sme_private for select using (owns_sme(sme_id));
drop policy if exists sme_private_owner_update on sme_private;
create policy sme_private_owner_update on sme_private for update using (owns_sme(sme_id)) with check (owns_sme(sme_id));
drop policy if exists sme_private_division_all on sme_private;
create policy sme_private_division_all on sme_private for all using (is_division()) with check (is_division());
create or replace trigger trg_touch_sme_private before update on sme_private for each row execute function touch_updated_at();

-- A seller may change their bank details, but that always clears the
-- verification. Only the Division can mark an account verified.
create or replace function guard_sme_private()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or is_division() then
    if new.bank_verified and not coalesce(old.bank_verified, false) then
      new.bank_verified_at := now();
      new.bank_verified_by := auth.uid();
    end if;
    return new;
  end if;
  if (new.bank_name, new.account_name, new.account_number)
       is distinct from (old.bank_name, old.account_name, old.account_number) then
    new.bank_verified := false;
    new.bank_verified_at := null;
    new.bank_verified_by := null;
  else
    new.bank_verified := old.bank_verified;
    new.bank_verified_at := old.bank_verified_at;
    new.bank_verified_by := old.bank_verified_by;
  end if;
  return new;
end $$;
create or replace trigger trg_guard_sme_private before update on sme_private
  for each row execute function guard_sme_private();

-- The legacy private columns on smes stay (empty) because dropping
-- columns needs an interactive confirmation in the tooling used. They
-- are unreadable through the API. To remove them from the SQL editor:
--   alter table smes drop column contact_name, drop column phone, drop column email,
--     drop column ipa_number, drop column tin, drop column bank_name,
--     drop column account_name, drop column account_number;
alter table smes alter column contact_name set default '';
alter table smes alter column phone set default '';

alter table smes add column if not exists is_sample boolean not null default false;
comment on column smes.is_sample is 'Placeholder data for the design preview. Remove before launch: delete from smes where is_sample;';

-- the API roles may read and write only the public columns of smes
revoke select, insert, update on smes from anon, authenticated;
grant select (id, slug, owner_id, registered_name, trading_name, district, llg,
              primary_industry, secondary_industry, ipa_status, description,
              photo_ref, hero_photo_ref, featured, consent, approved, approved_at,
              approved_by, notes, created_at, updated_at, is_sample)
  on smes to anon, authenticated;
grant insert (slug, registered_name, trading_name, district, llg, primary_industry,
              secondary_industry, ipa_status, description, photo_ref, hero_photo_ref,
              featured, consent, approved, approved_at, approved_by, notes, owner_id)
  on smes to authenticated;
grant update (registered_name, trading_name, llg, secondary_industry, ipa_status,
              description, photo_ref, hero_photo_ref, featured, approved, approved_at,
              approved_by, notes, owner_id)
  on smes to authenticated;

-- Sellers may not change approval, featuring, ownership or district.
create or replace function guard_sme_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or is_division() then return new; end if;
  new.approved := old.approved; new.approved_at := old.approved_at; new.approved_by := old.approved_by;
  new.featured := old.featured; new.owner_id := old.owner_id; new.notes := old.notes;
  new.district := old.district; new.slug := old.slug; new.consent := old.consent;
  return new;
end $$;
create or replace trigger trg_guard_sme_update before update on smes for each row execute function guard_sme_update();

-- approving an application files the private details separately
create or replace function approve_application(app_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  a seller_applications%rowtype; new_sme uuid; base_slug text; try_slug text; n int := 1;
begin
  if not is_division() then raise exception 'Only Division staff may approve applications'; end if;
  select * into a from seller_applications where id = app_id;
  if not found then raise exception 'No such application'; end if;
  if a.status = 'approved' then raise exception 'Already approved'; end if;
  base_slug := regexp_replace(lower(a.business_name), '[^a-z0-9]+', '', 'g');
  base_slug := left(coalesce(nullif(base_slug,''), 'sme'), 16);
  try_slug := base_slug;
  while exists (select 1 from smes where slug = try_slug) loop
    n := n + 1;
    try_slug := left(base_slug, 14) || n::text;
  end loop;
  insert into smes (slug, registered_name, district, llg, primary_industry, ipa_status,
                    consent, approved, approved_at, approved_by)
  values (try_slug, a.business_name, a.district, a.llg, a.primary_industry, a.ipa_status,
          a.consent, true, now(), auth.uid())
  returning id into new_sme;
  insert into sme_private (sme_id, contact_name, phone, email)
  values (new_sme, a.contact_name, a.phone, a.email);
  insert into products (sme_id, name, category, price, unit, description, status)
  select new_sme, p.name, coalesce(p.category, a.primary_industry), coalesce(p.price, 0), p.unit, p.description, 'in_review'
  from application_products p where p.application_id = app_id;
  update seller_applications set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid(), created_sme_id = new_sme
  where id = app_id;
  return new_sme;
end $$;


-- ============================================================
-- 2. CATALOGUE: badge, display order, public views
-- ============================================================
alter table products add column if not exists badge text;
alter table products add column if not exists sort_key integer not null default 0;
comment on column products.badge is 'Short merchandising label shown on the card, e.g. Best seller, New, Bulk.';
comment on column products.sort_key is 'Featured order in the catalogue (lower first).';

create or replace view public_catalogue with (security_invoker = true) as
select p.id as product_id, p.name, p.category, p.price, p.unit, p.stock, p.description,
       p.perishable, p.shippable,
       s.id as sme_id, s.slug as sme_slug, coalesce(s.trading_name, s.registered_name) as sme_name,
       s.district, s.primary_industry,
       (select pi.storage_path from product_images pi where pi.product_id = p.id order by pi.sort_order limit 1) as photo,
       p.badge, p.sort_key, p.created_at
from products p join smes s on s.id = p.sme_id
where p.status = 'live' and s.approved = true;

create or replace view public_smes with (security_invoker = true) as
select s.id, s.slug, coalesce(s.trading_name, s.registered_name) as name, s.registered_name,
       s.district, s.llg, s.primary_industry, s.secondary_industry, s.description,
       s.photo_ref, s.hero_photo_ref, s.featured, s.is_sample
from smes s
where s.approved = true;
grant select on public_catalogue, public_smes to anon, authenticated;


-- ============================================================
-- 3. PLATFORM SETTINGS
--    Figures are placeholders until the Division signs off D2/D4
--    (docs/outreach/decisions.md).
-- ============================================================
create table if not exists platform_settings (
  id                     boolean primary key default true check (id),
  platform_rate          numeric(5,2) not null default 10.00 check (platform_rate between 0 and 100),
  delivery_fee           numeric(10,2) not null default 15.00 check (delivery_fee >= 0),
  free_delivery_over     numeric(10,2) not null default 150.00,
  min_order              numeric(10,2) not null default 15.00,
  payout_hold_days       integer not null default 5 check (payout_hold_days >= 0),
  card_payments_enabled  boolean not null default false,
  bank_transfer_details  text,
  updated_at             timestamptz not null default now()
);
insert into platform_settings (id) values (true) on conflict (id) do nothing;
alter table platform_settings enable row level security;
drop policy if exists settings_public_read on platform_settings;
create policy settings_public_read on platform_settings for select using (true);
drop policy if exists settings_division_update on platform_settings;
create policy settings_division_update on platform_settings for update using (is_division()) with check (is_division());
create or replace trigger trg_touch_settings before update on platform_settings for each row execute function touch_updated_at();


-- ============================================================
-- 4. ORDERS: only through place_order()
-- ============================================================
alter policy orders_create on orders with check (false);
alter policy order_items_create on order_items with check (false);

create or replace function basket_lines(p_items jsonb)
returns table (product_id uuid, sme_id uuid, name text, unit text, price numeric, stock integer, qty integer)
language sql stable security definer set search_path = public as $$
  select p.id, p.sme_id, p.name, p.unit, p.price, p.stock,
         greatest(1, least(999, coalesce((x->>'qty')::int, 1)))
  from jsonb_array_elements(p_items) x
  join products p on p.id = (x->>'product_id')::uuid
  join smes m on m.id = p.sme_id
  where p.status = 'live' and m.approved;
$$;

create or replace function place_order(p_order jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  s platform_settings%rowtype;
  v_name text := btrim(coalesce(p_order->>'buyer_name', ''));
  v_phone text := btrim(coalesce(p_order->>'buyer_phone', ''));
  v_email text := nullif(btrim(coalesce(p_order->>'buyer_email', '')), '');
  v_gift boolean := coalesce((p_order->>'is_gift')::boolean, false);
  v_rname text := nullif(btrim(coalesce(p_order->>'recipient_name', '')), '');
  v_rphone text := nullif(btrim(coalesce(p_order->>'recipient_phone', '')), '');
  v_fulfil fulfilment_method;
  v_pay payment_method;
  v_district district;
  v_address text := nullif(btrim(coalesce(p_order->>'delivery_address', '')), '');
  v_items jsonb := coalesce(p_order->'items', '[]'::jsonb);
  v_basket uuid := gen_random_uuid();
  v_subtotal numeric(10,2) := 0;
  v_delivery numeric(10,2) := 0;
  v_first boolean := true;
  v_order_id uuid;
  v_out jsonb;
  v_count int;
  r record;
begin
  select * into s from platform_settings where id;

  if length(v_name) < 2 or length(v_name) > 100 then raise exception 'Please enter your name.'; end if;
  if v_phone !~ '^\+?[0-9 ]{7,20}$' then raise exception 'Please enter a valid mobile number.'; end if;
  if v_gift and (v_rname is null or v_rphone is null) then
    raise exception 'Please enter the name and phone number of the person receiving the order.';
  end if;

  begin
    v_fulfil := (p_order->>'fulfilment')::fulfilment_method;
    v_pay := (p_order->>'payment_method')::payment_method;
  exception when others then
    raise exception 'Please choose how to pay and how to receive the order.';
  end;
  if v_fulfil is null or v_pay is null then raise exception 'Please choose how to pay and how to receive the order.'; end if;
  if v_pay in ('card','bsp_pay') and not s.card_payments_enabled then
    raise exception 'Card payments are not available yet. Please pay through an agent or by bank transfer.';
  end if;
  if nullif(p_order->>'delivery_district', '') is not null then
    v_district := (p_order->>'delivery_district')::district;
  end if;
  if v_fulfil = 'delivery' and v_address is null then raise exception 'Please enter a delivery address.'; end if;

  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 then raise exception 'Your basket is empty.'; end if;
  if jsonb_array_length(v_items) > 50 then raise exception 'Too many items in one order.'; end if;

  -- a simple brake on abuse: at most 10 unpaid baskets per phone per hour
  if (select count(distinct basket_ref) from orders
      where buyer_phone = v_phone and status = 'pending_payment' and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many orders from this number. Please try again later.';
  end if;

  select count(*), coalesce(sum(price * qty), 0) into v_count, v_subtotal from basket_lines(v_items);
  if v_count <> jsonb_array_length(v_items) then
    raise exception 'Some items are no longer available. Please refresh your basket.';
  end if;
  for r in select * from basket_lines(v_items) where stock is not null and stock < qty loop
    raise exception 'Only % left of %.', r.stock, r.name;
  end loop;

  if v_subtotal < s.min_order then raise exception 'The minimum order is K%.', s.min_order; end if;
  if v_fulfil = 'delivery' and v_subtotal < s.free_delivery_over then v_delivery := s.delivery_fee; end if;

  -- one order per business, sharing one basket reference
  for r in select l.sme_id from basket_lines(v_items) l group by l.sme_id order by l.sme_id loop
    insert into orders (basket_ref, buyer_id, sme_id, buyer_name, buyer_phone, buyer_email,
                        is_gift, recipient_name, recipient_phone, fulfilment, delivery_address,
                        delivery_district, payment_method, platform_rate, delivery_fee)
    values (v_basket, auth.uid(), r.sme_id, v_name, v_phone, v_email,
            v_gift, v_rname, v_rphone, v_fulfil, v_address,
            v_district, v_pay, s.platform_rate, case when v_first then v_delivery else 0 end)
    returning id into v_order_id;
    v_first := false;

    insert into order_items (order_id, product_id, product_name, unit, unit_price, quantity, line_total)
    select v_order_id, l.product_id, l.name, l.unit, l.price, l.qty, round(l.price * l.qty, 2)
    from basket_lines(v_items) l where l.sme_id = r.sme_id;
  end loop;

  select jsonb_agg(jsonb_build_object(
           'order_number', o.order_number,
           'business', coalesce(m.trading_name, m.registered_name),
           'total', o.total) order by o.order_number)
    into v_out
  from orders o join smes m on m.id = o.sme_id
  where o.basket_ref = v_basket;

  return jsonb_build_object(
    'basket_ref', v_basket, 'orders', v_out,
    'subtotal', v_subtotal, 'delivery_fee', v_delivery, 'total', v_subtotal + v_delivery,
    'payment_method', v_pay, 'bank_transfer_details', s.bank_transfer_details
  );
end $$;
comment on function place_order is
  'The only way to create orders. Prices, fees and delivery are computed here, never taken from the browser.';

-- a buyer can check a basket by its reference, without seeing anyone's details
create or replace function basket_status(p_ref uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'order_number', o.order_number,
           'business', coalesce(m.trading_name, m.registered_name),
           'status', o.status,
           'payment_method', o.payment_method,
           'total', o.total,
           'created_at', o.created_at) order by o.order_number), '[]'::jsonb)
  from orders o join smes m on m.id = o.sme_id
  where o.basket_ref = p_ref;
$$;


-- ============================================================
-- 5. SELLER APPLICATIONS
-- ============================================================
create or replace function application_is_open(app uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from seller_applications a
                 where a.id = app and a.status = 'pending' and a.created_at > now() - interval '1 hour');
$$;
alter policy app_products_insert on application_products with check (application_is_open(application_id));
alter policy app_photos_insert on application_photos with check (application_is_open(application_id));

create or replace function submit_application(p_app jsonb, p_products jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id uuid; v_ref text; v_out jsonb;
begin
  if length(btrim(coalesce(p_app->>'business_name',''))) < 2 then raise exception 'Please enter the business name.'; end if;
  if length(btrim(coalesce(p_app->>'contact_name',''))) < 2 then raise exception 'Please enter a contact name.'; end if;
  if coalesce(p_app->>'phone','') !~ '^\+?[0-9 ]{7,20}$' then raise exception 'Please enter a valid phone number.'; end if;
  if not coalesce((p_app->>'consent')::boolean, false) then raise exception 'Please agree to the terms to apply.'; end if;
  if jsonb_typeof(p_products) <> 'array' or jsonb_array_length(p_products) > 30 then raise exception 'Too many products.'; end if;

  insert into seller_applications (business_name, district, llg, primary_industry, contact_name, phone, email,
                                   ipa_status, years_trading, staff_count, message, wants_help, consent, submitted_from)
  values (btrim(p_app->>'business_name'), (p_app->>'district')::district, nullif(p_app->>'llg',''),
          (p_app->>'primary_industry')::industry, btrim(p_app->>'contact_name'), btrim(p_app->>'phone'),
          nullif(p_app->>'email',''), p_app->>'ipa_status', nullif(p_app->>'years_trading',''),
          nullif(p_app->>'staff_count',''), nullif(p_app->>'message',''),
          coalesce((p_app->>'wants_help')::boolean, false), true,
          case when p_app->>'submitted_from' = 'field' then 'field' else 'web' end)
  returning id, reference into v_id, v_ref;

  insert into application_products (application_id, name, category, price, unit, stock, description, sort_order)
  select v_id, left(btrim(x->>'name'), 120), (p_app->>'primary_industry')::industry,
         nullif(x->>'price','')::numeric, nullif(x->>'unit',''), nullif(x->>'stock',''),
         nullif(x->>'description',''), coalesce((x->>'sort_order')::int, 0)
  from jsonb_array_elements(p_products) x
  where length(btrim(coalesce(x->>'name',''))) > 0;

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'sort_order', sort_order) order by sort_order), '[]'::jsonb)
    into v_out from application_products where application_id = v_id;

  return jsonb_build_object('id', v_id, 'reference', v_ref, 'products', v_out);
end $$;


-- ============================================================
-- 6. PAYOUTS: prepared by one person, approved by another,
--    paid only to a verified bank account
-- ============================================================
do $$ begin
  create type payout_status as enum ('draft','approved','paid','cancelled');
exception when duplicate_object then null; end $$;

create table if not exists payouts (
  id              uuid primary key default gen_random_uuid(),
  sme_id          uuid not null references smes(id) on delete restrict,
  amount          numeric(10,2) not null check (amount >= 0),
  period_end      date not null default current_date,
  status          payout_status not null default 'draft',
  bank_reference  text,
  created_by      uuid references profiles(id) default auth.uid(),
  created_at      timestamptz not null default now(),
  approved_by     uuid references profiles(id),
  approved_at     timestamptz,
  paid_by         uuid references profiles(id),
  paid_at         timestamptz,
  notes           text
);
create table if not exists payout_orders (
  payout_id  uuid not null references payouts(id) on delete cascade,
  order_id   uuid not null unique references orders(id) on delete restrict,
  primary key (payout_id, order_id)
);
create index if not exists idx_payouts_sme on payouts(sme_id);

alter table payouts enable row level security;
alter table payout_orders enable row level security;
drop policy if exists payouts_owner_read on payouts;
create policy payouts_owner_read on payouts for select using (owns_sme(sme_id));
drop policy if exists payouts_division_all on payouts;
create policy payouts_division_all on payouts for all using (is_division()) with check (is_division());
drop policy if exists payout_orders_owner_read on payout_orders;
create policy payout_orders_owner_read on payout_orders for select using (
  exists (select 1 from payouts p where p.id = payout_orders.payout_id and owns_sme(p.sme_id)));
drop policy if exists payout_orders_division_all on payout_orders;
create policy payout_orders_division_all on payout_orders for all using (is_division()) with check (is_division());

create or replace function guard_payout()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'approved' then
      if old.status <> 'draft' then raise exception 'Only a draft payout can be approved.'; end if;
      if auth.uid() is not null and auth.uid() = old.created_by then
        raise exception 'A payout must be approved by someone other than the person who prepared it.';
      end if;
      new.approved_by := auth.uid(); new.approved_at := now();
    elsif new.status = 'paid' then
      if old.status <> 'approved' then raise exception 'A payout must be approved before it is paid.'; end if;
      if not exists (select 1 from sme_private where sme_id = new.sme_id and bank_verified) then
        raise exception 'This business''s bank account has not been verified.';
      end if;
      new.paid_by := auth.uid(); new.paid_at := now();
    end if;
  end if;
  return new;
end $$;
create or replace trigger trg_guard_payout before update on payouts for each row execute function guard_payout();

-- what each business is owed, split into held / available / paid out
create or replace view seller_balances with (security_invoker = true) as
select o.sme_id,
       coalesce(sum(o.seller_net) filter (where o.status in ('paid','processing','ready')
                  or (o.status = 'fulfilled' and o.updated_at > now() - make_interval(days => (select payout_hold_days from platform_settings where id)))), 0) as held,
       coalesce(sum(o.seller_net) filter (where o.status = 'fulfilled'
                  and o.updated_at <= now() - make_interval(days => (select payout_hold_days from platform_settings where id))
                  and not exists (select 1 from payout_orders po where po.order_id = o.id)), 0) as available,
       coalesce(sum(o.seller_net) filter (where exists (select 1 from payout_orders po join payouts p on p.id = po.payout_id
                                                       where po.order_id = o.id and p.status = 'paid')), 0) as paid_out
from orders o
group by o.sme_id;


-- ============================================================
-- 7. STORAGE: approved photos
--    product-photos is public to view; only the Division writes.
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('applications', 'applications', false, 2097152, array['image/jpeg','image/png'])
on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists photos_division_write on storage.objects;
create policy photos_division_write on storage.objects for insert to authenticated
  with check (bucket_id = 'product-photos' and is_division());
drop policy if exists photos_division_update on storage.objects;
create policy photos_division_update on storage.objects for update to authenticated
  using (bucket_id = 'product-photos' and is_division())
  with check (bucket_id = 'product-photos' and is_division());
drop policy if exists photos_division_delete on storage.objects;
create policy photos_division_delete on storage.objects for delete to authenticated
  using (bucket_id = 'product-photos' and is_division());


-- ============================================================
-- 8. FUNCTION HARDENING (Supabase security advisor)
-- ============================================================
alter function public.log_price_change() set search_path = public;
alter function public.recalc_order_totals() set search_path = public;
alter function public.set_order_number() set search_path = public;
alter function public.set_application_reference() set search_path = public;
alter function public.touch_updated_at() set search_path = public;

-- trigger and internal functions are never called directly
revoke execute on function public.guard_order_status() from public, anon, authenticated;
revoke execute on function public.guard_product_status() from public, anon, authenticated;
revoke execute on function public.guard_payout() from public, anon, authenticated;
revoke execute on function public.guard_sme_private() from public, anon, authenticated;
revoke execute on function public.guard_sme_update() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.log_price_change() from public, anon, authenticated;
revoke execute on function public.recalc_order_totals() from public, anon, authenticated;
revoke execute on function public.set_order_number() from public, anon, authenticated;
revoke execute on function public.set_application_reference() from public, anon, authenticated;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;
revoke execute on function public.basket_lines(jsonb) from public, anon, authenticated;

revoke execute on function public.approve_application(uuid) from public, anon;
grant execute on function public.approve_application(uuid) to authenticated;

-- intentionally public; each validates its own input
grant execute on function public.place_order(jsonb) to anon, authenticated;
grant execute on function public.submit_application(jsonb, jsonb) to anon, authenticated;
grant execute on function public.basket_status(uuid) to anon, authenticated;

-- used inside row level security policies, so the API roles must be able to run them
comment on function public.is_division() is 'RLS helper: is the caller Division staff? Must stay executable by anon/authenticated.';
comment on function public.owns_sme(uuid) is 'RLS helper: does the caller own this business? Must stay executable by anon/authenticated.';
comment on function public.application_is_open(uuid) is 'RLS helper: is this application still open for uploads (pending, under 1 hour)?';

-- ============================================================
--  END
-- ============================================================
