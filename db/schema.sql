-- ============================================================
--  MaketPles ENB — Database Schema
--  Division of Commerce & Industry, East New Britain
-- ------------------------------------------------------------
--  Run this in the Supabase SQL editor on a NEW project.
--  Run it once, top to bottom. It is safe to re-run: every
--  statement uses IF NOT EXISTS or DROP ... IF EXISTS first.
--
--  Sections:
--    1. Reference types
--    2. Tables
--    3. Indexes
--    4. Triggers (price history, timestamps, order totals)
--    5. Row Level Security policies
--    6. Helper views
-- ============================================================


-- ============================================================
-- 1. REFERENCE TYPES
--    The seven industries come from the bi-annual conference
--    SME listing. The four districts are fixed.
-- ============================================================

do $$ begin
  create type industry as enum (
    'retail', 'wholesale', 'tailoring', 'crafts',
    'processing', 'produce', 'foodcrops'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type district as enum ('Gazelle', 'Kokopo', 'Rabaul', 'Pomio');
exception when duplicate_object then null; end $$;

do $$ begin
  create type listing_status as enum ('draft', 'in_review', 'live', 'needs_changes', 'withdrawn');
exception when duplicate_object then null; end $$;

do $$ begin
  create type order_status as enum (
    'pending_payment', 'paid', 'processing', 'ready',
    'fulfilled', 'cancelled', 'refunded', 'disputed'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_method as enum ('card', 'bsp_pay', 'agent_cash', 'bank_transfer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type fulfilment_method as enum ('sme_pickup', 'agent_handoff', 'delivery');
exception when duplicate_object then null; end $$;

do $$ begin
  create type app_role as enum ('buyer', 'seller', 'agent', 'division_staff', 'division_admin');
exception when duplicate_object then null; end $$;


-- ============================================================
-- 2. TABLES
-- ============================================================

-- ---------- 2.1 profiles ----------
-- One row per authenticated user. Extends Supabase's auth.users.
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text,
  phone         text,
  role          app_role not null default 'buyer',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table profiles is
  'Extends auth.users with a role. Role determines what RLS allows.';


-- ---------- 2.2 smes ----------
create table if not exists smes (
  id                  uuid primary key default gen_random_uuid(),
  slug                text unique not null,
  owner_id            uuid references profiles(id) on delete set null,

  registered_name     text not null,
  trading_name        text,
  district            district not null,
  llg                 text,

  primary_industry    industry not null,
  secondary_industry  industry,

  ipa_status          text default 'Not registered',
  ipa_number          text,
  tin                 text,

  contact_name        text not null,
  phone               text not null,
  email               text,

  bank_name           text,
  account_name        text,
  account_number      text,

  description         text,
  photo_ref           text,
  hero_photo_ref      text,
  featured            boolean not null default false,

  consent             boolean not null default false,
  approved            boolean not null default false,
  approved_at         timestamptz,
  approved_by         uuid references profiles(id),

  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on column smes.owner_id is
  'The seller login for this business. Null until an account is issued.';
comment on column smes.approved is
  'Only approved businesses appear on the public site.';
comment on column smes.featured is
  'Featured businesses appear in the homepage slideshow.';


-- ---------- 2.3 products ----------
create table if not exists products (
  id             uuid primary key default gen_random_uuid(),
  sme_id         uuid not null references smes(id) on delete cascade,

  name           text not null,
  category       industry not null,
  price          numeric(10,2) not null check (price >= 0),
  unit           text,
  stock          integer default 0 check (stock >= 0),
  description    text,

  perishable     boolean not null default false,
  shippable      boolean not null default true,

  status         listing_status not null default 'draft',
  review_note    text,
  reviewed_at    timestamptz,
  reviewed_by    uuid references profiles(id),

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

comment on column products.status is
  'Only status = live appears publicly. New listings and material edits go to in_review.';
comment on column products.review_note is
  'Reason returned to the seller when a listing needs changes.';


-- ---------- 2.4 product_images ----------
create table if not exists product_images (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references products(id) on delete cascade,
  storage_path text not null,
  photo_ref   text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

comment on column product_images.photo_ref is
  'Original filename from field collection, e.g. KOKOPO_Vunamami_cocoa_01.jpg';


-- ---------- 2.5 price_history ----------
-- Every price change is logged. This doubles as economic data
-- for the Division's reporting mandate.
create table if not exists price_history (
  id          bigserial primary key,
  product_id  uuid not null references products(id) on delete cascade,
  old_price   numeric(10,2),
  new_price   numeric(10,2) not null,
  changed_by  uuid references profiles(id),
  changed_at  timestamptz not null default now()
);


-- ---------- 2.6 agents ----------
create table if not exists agents (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid unique references profiles(id) on delete set null,
  full_name       text not null,
  phone           text not null,
  district        district not null,
  location        text,
  commission_rate numeric(5,2) not null default 5.00
                    check (commission_rate >= 0 and commission_rate <= 100),
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on column agents.commission_rate is
  'Percentage of order value paid to the agent. Set by the Division.';


-- ---------- 2.7 orders ----------
-- One order per SME. A basket spanning three businesses
-- becomes three orders sharing one basket_ref.
create table if not exists orders (
  id                 uuid primary key default gen_random_uuid(),
  order_number       text unique not null,
  basket_ref         uuid not null,

  buyer_id           uuid references profiles(id) on delete set null,
  sme_id             uuid not null references smes(id) on delete restrict,
  agent_id           uuid references agents(id) on delete set null,

  buyer_name         text not null,
  buyer_phone        text not null,
  buyer_email        text,

  -- "Send home": buying on behalf of someone in the province
  is_gift            boolean not null default false,
  recipient_name     text,
  recipient_phone    text,

  fulfilment         fulfilment_method not null,
  delivery_address   text,
  delivery_district  district,

  payment_method     payment_method not null,
  status             order_status not null default 'pending_payment',

  subtotal           numeric(10,2) not null default 0,
  delivery_fee       numeric(10,2) not null default 0,
  total              numeric(10,2) not null default 0,

  platform_rate      numeric(5,2) not null default 10.00,
  platform_fee       numeric(10,2) not null default 0,
  agent_fee          numeric(10,2) not null default 0,
  seller_net         numeric(10,2) not null default 0,

  -- payment gateway fields, populated at integration time
  gateway_ref        text,
  gateway_payload    jsonb,
  paid_at            timestamptz,

  notes              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on column orders.basket_ref is
  'Shared by every order created from the same checkout, so a multi-seller basket can be traced.';
comment on column orders.seller_net is
  'What the SME is owed: subtotal less platform fee and agent commission.';
comment on column orders.gateway_payload is
  'Raw confirmation from the payment gateway, kept for reconciliation.';


-- ---------- 2.8 order_items ----------
-- Prices are COPIED here at the moment of sale. Later price
-- changes by the seller must never alter a completed order.
create table if not exists order_items (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references orders(id) on delete cascade,
  product_id     uuid references products(id) on delete set null,

  product_name   text not null,
  unit           text,
  unit_price     numeric(10,2) not null,
  quantity       integer not null check (quantity > 0),
  line_total     numeric(10,2) not null,

  created_at     timestamptz not null default now()
);

comment on table order_items is
  'product_name and unit_price are snapshots taken at purchase, not live references.';


-- ---------- 2.9 seller_applications ----------
create table if not exists seller_applications (
  id                uuid primary key default gen_random_uuid(),
  business_name     text not null,
  district          district not null,
  primary_industry  industry not null,
  contact_name      text not null,
  phone             text not null,
  email             text,
  ipa_status        text,
  message           text,

  status            text not null default 'pending',
  review_note       text,
  reviewed_at       timestamptz,
  reviewed_by       uuid references profiles(id),
  created_sme_id    uuid references smes(id) on delete set null,

  created_at        timestamptz not null default now()
);


-- ---------- 2.10 notices ----------
create table if not exists notices (
  id           uuid primary key default gen_random_uuid(),
  category     text not null default 'ANNOUNCEMENT',
  title        text not null,
  body         text not null,
  published    boolean not null default false,
  published_at timestamptz,
  author_id    uuid references profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);


-- ============================================================
-- 3. INDEXES
-- ============================================================

create index if not exists idx_smes_district      on smes(district);
create index if not exists idx_smes_industry      on smes(primary_industry);
create index if not exists idx_smes_approved      on smes(approved) where approved = true;
create index if not exists idx_smes_owner         on smes(owner_id);

create index if not exists idx_products_sme       on products(sme_id);
create index if not exists idx_products_category  on products(category);
create index if not exists idx_products_live      on products(status) where status = 'live';

create index if not exists idx_orders_sme         on orders(sme_id);
create index if not exists idx_orders_buyer       on orders(buyer_id);
create index if not exists idx_orders_agent       on orders(agent_id);
create index if not exists idx_orders_status      on orders(status);
create index if not exists idx_orders_basket      on orders(basket_ref);
create index if not exists idx_orders_created     on orders(created_at desc);

create index if not exists idx_order_items_order  on order_items(order_id);
create index if not exists idx_price_hist_product on price_history(product_id, changed_at desc);


-- ============================================================
-- 4. TRIGGERS
-- ============================================================

-- ---------- 4.0 shared helpers ----------
-- Defined here because the guard triggers below use them.
-- security definer so they can read profiles without being
-- caught by the policies on profiles itself.
create or replace function is_division()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role in ('division_staff','division_admin')
  );
$$;

create or replace function owns_sme(target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from smes where id = target and owner_id = auth.uid()
  );
$$;

-- ---------- 4.1 keep updated_at current ----------
create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles','smes','products','agents','orders','notices']
  loop
    execute format('drop trigger if exists trg_touch_%1$s on %1$s', t);
    execute format(
      'create trigger trg_touch_%1$s before update on %1$s
       for each row execute function touch_updated_at()', t);
  end loop;
end $$;


-- ---------- 4.2 log every price change ----------
create or replace function log_price_change()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.price is distinct from old.price then
    insert into price_history (product_id, old_price, new_price, changed_by)
    values (new.id, old.price, new.price, auth.uid());
  elsif tg_op = 'INSERT' then
    insert into price_history (product_id, old_price, new_price, changed_by)
    values (new.id, null, new.price, auth.uid());
  end if;
  return new;
end $$;

drop trigger if exists trg_price_history on products;
create trigger trg_price_history
  after insert or update of price on products
  for each row execute function log_price_change();


-- ---------- 4.3 recalculate order money ----------
-- Keeps subtotal, fees and seller_net consistent whenever
-- items change. Never trust these figures from the client.
create or replace function recalc_order_totals()
returns trigger language plpgsql as $$
declare
  oid uuid;
  v_subtotal numeric(10,2);
  v_order orders%rowtype;
  v_agent_rate numeric(5,2) := 0;
begin
  oid := coalesce(new.order_id, old.order_id);

  select coalesce(sum(line_total), 0) into v_subtotal
    from order_items where order_id = oid;

  select * into v_order from orders where id = oid;
  if not found then return null; end if;

  if v_order.agent_id is not null then
    select commission_rate into v_agent_rate from agents where id = v_order.agent_id;
    v_agent_rate := coalesce(v_agent_rate, 0);
  end if;

  update orders set
    subtotal    = v_subtotal,
    platform_fee = round(v_subtotal * platform_rate / 100, 2),
    agent_fee    = round(v_subtotal * v_agent_rate / 100, 2),
    total        = v_subtotal + delivery_fee,
    seller_net   = v_subtotal
                   - round(v_subtotal * platform_rate / 100, 2)
                   - round(v_subtotal * v_agent_rate / 100, 2)
  where id = oid;

  return null;
end $$;

drop trigger if exists trg_recalc_totals on order_items;
create trigger trg_recalc_totals
  after insert or update or delete on order_items
  for each row execute function recalc_order_totals();


-- ---------- 4.4 human-readable order numbers ----------
create sequence if not exists order_seq start 1000;

create or replace function set_order_number()
returns trigger language plpgsql as $$
begin
  if new.order_number is null or new.order_number = '' then
    new.order_number := 'ENB-' || nextval('order_seq')::text;
  end if;
  if new.basket_ref is null then
    new.basket_ref := gen_random_uuid();
  end if;
  return new;
end $$;

drop trigger if exists trg_order_number on orders;
create trigger trg_order_number
  before insert on orders
  for each row execute function set_order_number();


-- ---------- 4.5 guard product status transitions ----------
-- Publishing is the Division's decision. A seller may keep a
-- listing in draft, submit it for review, or withdraw it —
-- but may not move it to 'live' themselves. A listing that is
-- already live stays live while they edit price or stock.
-- Enforced here rather than in a policy, because a policy
-- cannot read the row's own previous value without recursion.
create or replace function guard_product_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- the Division and the service role bypass this entirely
  if auth.uid() is null or is_division() then
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'live' then
      raise exception
        'Listings are published by the Division. Submit for review instead.'
        using errcode = 'check_violation';
    end if;
    if new.status not in ('draft','in_review','withdrawn') then
      raise exception 'A seller cannot set a listing to %', new.status
        using errcode = 'check_violation';
    end if;
  end if;

  -- a seller cannot clear a review note or backdate a review
  new.reviewed_by := old.reviewed_by;
  new.reviewed_at := old.reviewed_at;

  return new;
end $$;

drop trigger if exists trg_guard_product_status on products;
create trigger trg_guard_product_status
  before update on products
  for each row execute function guard_product_status();


-- ---------- 4.6 guard order status transitions ----------
-- A seller moves an order through fulfilment. Payment status
-- is set only by the server after the gateway confirms, so
-- 'paid', 'refunded' and 'cancelled' are not available to them.
create or replace function guard_order_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or is_division() then
    return new;
  end if;

  if new.status is distinct from old.status then
    if old.status = 'pending_payment' then
      raise exception
        'This order is not paid yet. Payment is confirmed by the payment gateway.'
        using errcode = 'check_violation';
    end if;
    if new.status not in ('processing','ready','fulfilled','disputed') then
      raise exception 'A seller cannot set an order to %', new.status
        using errcode = 'check_violation';
    end if;
  end if;

  -- money and payment fields are never writable by a seller
  new.subtotal       := old.subtotal;
  new.delivery_fee   := old.delivery_fee;
  new.total          := old.total;
  new.platform_rate  := old.platform_rate;
  new.platform_fee   := old.platform_fee;
  new.agent_fee      := old.agent_fee;
  new.seller_net     := old.seller_net;
  new.gateway_ref    := old.gateway_ref;
  new.gateway_payload:= old.gateway_payload;
  new.paid_at        := old.paid_at;

  return new;
end $$;

drop trigger if exists trg_guard_order_status on orders;
create trigger trg_guard_order_status
  before update on orders
  for each row execute function guard_order_status();


-- ---------- 4.7 create a profile for every new user ----------
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', '')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists trg_new_user on auth.users;
create trigger trg_new_user
  after insert on auth.users
  for each row execute function handle_new_user();


-- ============================================================
-- 5. ROW LEVEL SECURITY
--    Default position: nobody can see or do anything.
--    Policies below grant the minimum needed.
-- ============================================================

alter table profiles            enable row level security;
alter table smes                enable row level security;
alter table products            enable row level security;
alter table product_images      enable row level security;
alter table price_history       enable row level security;
alter table agents              enable row level security;
alter table orders              enable row level security;
alter table order_items         enable row level security;
alter table seller_applications enable row level security;
alter table notices             enable row level security;


-- ---------- 5.1 helpers ----------
-- is_division() and owns_sme() are defined in section 4.0,
-- because the guard triggers need them too.


-- ---------- 5.2 profiles ----------
drop policy if exists profiles_self_read on profiles;
create policy profiles_self_read on profiles
  for select using (id = auth.uid() or is_division());

drop policy if exists profiles_self_update on profiles;
create policy profiles_self_update on profiles
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from profiles where id = auth.uid()));
-- note: the role check stops a user promoting themselves.

drop policy if exists profiles_division_all on profiles;
create policy profiles_division_all on profiles
  for all using (is_division()) with check (is_division());


-- ---------- 5.3 smes ----------
-- Public sees approved businesses only.
drop policy if exists smes_public_read on smes;
create policy smes_public_read on smes
  for select using (approved = true);

drop policy if exists smes_owner_read on smes;
create policy smes_owner_read on smes
  for select using (owner_id = auth.uid() or is_division());

-- A seller may edit their own record, but may NOT approve
-- themselves or change their own district.
drop policy if exists smes_owner_update on smes;
create policy smes_owner_update on smes
  for update using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and approved = (select approved from smes s2 where s2.id = smes.id)
  );

drop policy if exists smes_division_all on smes;
create policy smes_division_all on smes
  for all using (is_division()) with check (is_division());


-- ---------- 5.4 products ----------
-- Public sees live products belonging to approved businesses.
drop policy if exists products_public_read on products;
create policy products_public_read on products
  for select using (
    status = 'live'
    and exists (select 1 from smes where smes.id = products.sme_id and smes.approved)
  );

drop policy if exists products_owner_read on products;
create policy products_owner_read on products
  for select using (owns_sme(sme_id) or is_division());

drop policy if exists products_owner_insert on products;
create policy products_owner_insert on products
  for insert with check (
    owns_sme(sme_id)
    and status in ('draft','in_review')   -- cannot self-publish
  );

-- A seller may edit their own listings. Which status changes
-- they are allowed to make is enforced by the
-- guard_product_status trigger in section 4, not here — a
-- policy cannot read the row's own previous value without
-- causing infinite recursion.
drop policy if exists products_owner_update on products;
create policy products_owner_update on products
  for update using (owns_sme(sme_id))
  with check (owns_sme(sme_id));

drop policy if exists products_owner_delete on products;
create policy products_owner_delete on products
  for delete using (owns_sme(sme_id));

drop policy if exists products_division_all on products;
create policy products_division_all on products
  for all using (is_division()) with check (is_division());


-- ---------- 5.5 product_images ----------
drop policy if exists images_public_read on product_images;
create policy images_public_read on product_images
  for select using (
    exists (
      select 1 from products p join smes s on s.id = p.sme_id
      where p.id = product_images.product_id and p.status = 'live' and s.approved
    )
  );

drop policy if exists images_owner_all on product_images;
create policy images_owner_all on product_images
  for all using (
    exists (select 1 from products p where p.id = product_images.product_id and owns_sme(p.sme_id))
    or is_division()
  )
  with check (
    exists (select 1 from products p where p.id = product_images.product_id and owns_sme(p.sme_id))
    or is_division()
  );


-- ---------- 5.6 price_history ----------
-- Read-only to sellers and the Division. Written by trigger only.
drop policy if exists price_hist_read on price_history;
create policy price_hist_read on price_history
  for select using (
    exists (select 1 from products p where p.id = price_history.product_id and owns_sme(p.sme_id))
    or is_division()
  );


-- ---------- 5.7 agents ----------
drop policy if exists agents_self_read on agents;
create policy agents_self_read on agents
  for select using (profile_id = auth.uid() or is_division());

drop policy if exists agents_division_all on agents;
create policy agents_division_all on agents
  for all using (is_division()) with check (is_division());


-- ---------- 5.8 orders ----------
-- A buyer sees their own. A seller sees orders against their
-- own business. An agent sees orders they placed. The Division
-- sees everything.
drop policy if exists orders_read on orders;
create policy orders_read on orders
  for select using (
    buyer_id = auth.uid()
    or owns_sme(sme_id)
    or exists (select 1 from agents a where a.id = orders.agent_id and a.profile_id = auth.uid())
    or is_division()
  );

drop policy if exists orders_create on orders;
create policy orders_create on orders
  for insert with check (
    status = 'pending_payment'          -- never created already paid
    and (buyer_id = auth.uid() or buyer_id is null)
  );

-- Sellers may update their own orders. Which status changes
-- they may make is enforced by the guard_order_status trigger
-- in section 4, not here — a policy cannot read the row's own
-- previous value without causing infinite recursion.
drop policy if exists orders_seller_update on orders;
create policy orders_seller_update on orders
  for update using (owns_sme(sme_id))
  with check (owns_sme(sme_id));

drop policy if exists orders_division_all on orders;
create policy orders_division_all on orders
  for all using (is_division()) with check (is_division());


-- ---------- 5.9 order_items ----------
drop policy if exists order_items_read on order_items;
create policy order_items_read on order_items
  for select using (
    exists (
      select 1 from orders o where o.id = order_items.order_id
      and (o.buyer_id = auth.uid() or owns_sme(o.sme_id) or is_division())
    )
  );

drop policy if exists order_items_create on order_items;
create policy order_items_create on order_items
  for insert with check (
    exists (
      select 1 from orders o
      where o.id = order_items.order_id and o.status = 'pending_payment'
    )
  );

drop policy if exists order_items_division_all on order_items;
create policy order_items_division_all on order_items
  for all using (is_division()) with check (is_division());


-- ---------- 5.10 seller_applications ----------
-- Anyone may apply. Only the Division may read or decide.
drop policy if exists applications_create on seller_applications;
create policy applications_create on seller_applications
  for insert with check (true);

drop policy if exists applications_division on seller_applications;
create policy applications_division on seller_applications
  for all using (is_division()) with check (is_division());


-- ---------- 5.11 notices ----------
drop policy if exists notices_public_read on notices;
create policy notices_public_read on notices
  for select using (published = true);

drop policy if exists notices_division_all on notices;
create policy notices_division_all on notices
  for all using (is_division()) with check (is_division());


-- ============================================================
-- 6. HELPER VIEWS
-- ============================================================

-- IMPORTANT
-- Every view below is created with security_invoker = true.
-- Without it a Postgres view runs with the privileges of whoever
-- created it, which silently bypasses the row level security on
-- the tables underneath — seller_payouts would hand every
-- business's revenue to anyone holding the public key.

-- ---------- 6.1 public catalogue ----------
-- What the website reads. Already filtered to live and approved.
create or replace view public_catalogue with (security_invoker = true) as
select
  p.id            as product_id,
  p.name,
  p.category,
  p.price,
  p.unit,
  p.stock,
  p.description,
  p.perishable,
  p.shippable,
  s.id            as sme_id,
  s.slug          as sme_slug,
  coalesce(s.trading_name, s.registered_name) as sme_name,
  s.district,
  s.primary_industry,
  (select pi.storage_path from product_images pi
    where pi.product_id = p.id order by pi.sort_order limit 1) as photo
from products p
join smes s on s.id = p.sme_id
where p.status = 'live' and s.approved = true;


-- ---------- 6.2 seller payout summary ----------
-- What each SME is owed, and what has already been settled.
create or replace view seller_payouts with (security_invoker = true) as
select
  s.id                as sme_id,
  s.registered_name,
  s.district,
  count(o.id)                                   as order_count,
  coalesce(sum(o.subtotal), 0)                  as gross_sales,
  coalesce(sum(o.platform_fee), 0)              as platform_fees,
  coalesce(sum(o.agent_fee), 0)                 as agent_fees,
  coalesce(sum(o.seller_net), 0)                as net_owed
from smes s
left join orders o
  on o.sme_id = s.id
  and o.status in ('paid','processing','ready','fulfilled')
group by s.id, s.registered_name, s.district;


-- ---------- 6.3 collection progress ----------
-- Mirrors the intake tool's dashboard, against live data.
create or replace view intake_progress with (security_invoker = true) as
select
  i.industry,
  count(s.id)                    as businesses,
  5                              as target,
  greatest(0, 5 - count(s.id))   as still_needed
from (select unnest(enum_range(null::industry)) as industry) i
left join smes s on s.primary_industry = i.industry
group by i.industry;


-- ============================================================
--  END
--  Next steps after running this:
--    1. Create a storage bucket named 'product-photos' (public)
--    2. Create your own division_admin account:
--         update profiles set role = 'division_admin'
--         where id = '<your auth user id>';
--    3. Import collected data using the SQL export from the
--       SME Intake tool.
-- ============================================================
