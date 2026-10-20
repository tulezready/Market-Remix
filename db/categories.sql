-- ============================================================
-- MaketPles ENB — the Division's business categories (migration 012)
-- Six main categories, each with sub-categories, from the Division's
-- "Type of MSME listing". The site's copy of the list is categories.js.
--
-- Part 1 must run (and commit) before part 2 — Postgres cannot use a new
-- enum value in the same transaction that adds it.
-- The old values (retail, wholesale, tailoring, crafts, processing,
-- produce, foodcrops) stay in the enum because Postgres cannot remove
-- them, but the forms no longer offer them.
-- ============================================================

-- ---------- part 1 ----------
alter type industry add value if not exists 'agriculture';
alter type industry add value if not exists 'tourism';
alter type industry add value if not exists 'fisheries';
alter type industry add value if not exists 'trade';
alter type industry add value if not exists 'transport';
alter type industry add value if not exists 'services';

-- ---------- part 2 ----------
-- which main category a sub-category belongs to (null = not a known sub-category)
create or replace function industry_of_sub(p_sub text) returns industry
language sql immutable as $$
  select case p_sub
    when 'cocoa'           then 'agriculture'
    when 'copra'           then 'agriculture'
    when 'galip'           then 'agriculture'
    when 'produce'         then 'agriculture'
    when 'accommodation'   then 'tourism'
    when 'tours'           then 'tourism'
    when 'food_service'    then 'tourism'
    when 'arts_crafts'     then 'tourism'
    when 'coastal_fishing' then 'fisheries'
    when 'fish_farming'    then 'fisheries'
    when 'trade_stores'    then 'trade'
    when 'distribution'    then 'trade'
    when 'pmv_taxi'        then 'transport'
    when 'cargo_rental'    then 'transport'
    when 'construction'    then 'services'
    when 'it_office'       then 'services'
  end::industry
$$;

alter table smes                 add column if not exists subcategory text;
alter table products             add column if not exists subcategory text;
alter table seller_applications  add column if not exists subcategory text;
alter table application_products add column if not exists subcategory text;

-- existing rows: old category -> new category and sub-category
update smes set primary_industry = 'agriculture', subcategory = 'produce' where primary_industry in ('produce','foodcrops');
update smes set primary_industry = 'agriculture', subcategory = 'cocoa'   where primary_industry = 'processing';
update smes set primary_industry = 'trade',       subcategory = 'trade_stores' where primary_industry = 'retail';
update smes set primary_industry = 'trade',       subcategory = 'distribution' where primary_industry = 'wholesale';
update seller_applications set primary_industry = 'agriculture', subcategory = 'produce' where primary_industry in ('produce','foodcrops');
update seller_applications set primary_industry = 'agriculture' where primary_industry = 'processing';
update seller_applications set primary_industry = 'trade', subcategory = 'trade_stores' where primary_industry = 'retail';
update seller_applications set primary_industry = 'trade', subcategory = 'distribution' where primary_industry = 'wholesale';
update application_products ap set category = a.primary_industry, subcategory = a.subcategory
  from seller_applications a where a.id = ap.application_id and ap.category in ('produce','foodcrops','processing','retail','wholesale');

-- products: by what they are, then by their old category
update products set category = 'agriculture', subcategory = 'cocoa'   where name ilike '%cocoa%';
update products set category = 'agriculture', subcategory = 'copra'   where name ilike '%copra%' or name ilike '%coconut%';
update products set category = 'agriculture', subcategory = 'galip'   where name ilike '%galip%';
update products set category = 'fisheries',   subcategory = 'coastal_fishing' where name ilike '%fish%' and category in ('processing','produce','foodcrops');
update products set category = 'trade',       subcategory = 'trade_stores' where name ilike '%rice%' and category in ('foodcrops','retail','wholesale');
update products set category = 'agriculture', subcategory = 'produce' where category in ('produce','foodcrops');
update products set category = 'agriculture', subcategory = null      where category = 'processing';
update products set category = 'trade',       subcategory = 'trade_stores' where category = 'retail';
update products set category = 'trade',       subcategory = 'distribution' where category = 'wholesale';
-- arts, crafts and tailoring: a type under Tourism & Hospitality (decided 20 Oct)
update smes set primary_industry = 'tourism', subcategory = 'arts_crafts' where primary_industry in ('crafts','tailoring');
update seller_applications set primary_industry = 'tourism', subcategory = 'arts_crafts' where primary_industry in ('crafts','tailoring');
update products set category = 'tourism', subcategory = 'arts_crafts' where category in ('crafts','tailoring');

alter table smes                 add constraint smes_subcategory_ok      check (subcategory is null or industry_of_sub(subcategory) = primary_industry) not valid;
alter table products             add constraint products_subcategory_ok  check (subcategory is null or industry_of_sub(subcategory) = category) not valid;
alter table seller_applications  add constraint apps_subcategory_ok      check (subcategory is null or industry_of_sub(subcategory) = primary_industry) not valid;
alter table application_products add constraint appprod_subcategory_ok   check (subcategory is null or industry_of_sub(subcategory) = category) not valid;
alter table smes                 validate constraint smes_subcategory_ok;
alter table products             validate constraint products_subcategory_ok;
alter table seller_applications  validate constraint apps_subcategory_ok;
alter table application_products validate constraint appprod_subcategory_ok;
create index if not exists idx_products_subcategory on products(subcategory);

-- smes has column-level grants: the public may read the new column, and the Division's insert may set it
grant select (subcategory) on smes to anon, authenticated;
grant insert (subcategory) on smes to authenticated;

-- public views: new column added at the end
create or replace view public_smes with (security_invoker = true) as
select id, slug, coalesce(trading_name, registered_name) as name, registered_name, district, llg,
       primary_industry, secondary_industry, description, photo_ref, hero_photo_ref, featured, is_sample, ward,
       subcategory
from smes s where approved = true;

create or replace view public_catalogue with (security_invoker = true) as
select p.id as product_id, p.name, p.category, p.price, p.unit, p.stock, p.description, p.perishable, p.shippable,
       s.id as sme_id, s.slug as sme_slug, coalesce(s.trading_name, s.registered_name) as sme_name, s.district,
       s.primary_industry,
       (select pi.storage_path from product_images pi where pi.product_id = p.id order by pi.sort_order limit 1) as photo,
       p.badge, p.sort_key, p.created_at,
       p.subcategory
from products p join smes s on s.id = p.sme_id
where p.status = 'live'::listing_status and s.approved = true;

-- the register form now sends a sub-category
create or replace function submit_application(p_app jsonb, p_products jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_id uuid; v_ref text; v_out jsonb; v_ind industry; v_sub text;
begin
  if length(btrim(coalesce(p_app->>'business_name',''))) < 2 then raise exception 'Please enter the business name.'; end if;
  if length(btrim(coalesce(p_app->>'contact_name',''))) < 2 then raise exception 'Please enter a contact name.'; end if;
  if coalesce(p_app->>'phone','') !~ '^\+?[0-9 ]{7,20}$' then raise exception 'Please enter a valid phone number.'; end if;
  if not coalesce((p_app->>'consent')::boolean, false) then raise exception 'Please agree to the terms to apply.'; end if;
  if jsonb_typeof(p_products) <> 'array' or jsonb_array_length(p_products) > 30 then raise exception 'Too many products.'; end if;
  v_ind := (p_app->>'primary_industry')::industry;
  v_sub := nullif(p_app->>'subcategory', '');
  if v_ind not in ('agriculture','tourism','fisheries','trade','transport','services') then
    raise exception 'Please choose one of the business categories.';
  end if;
  if v_sub is not null and industry_of_sub(v_sub) is distinct from v_ind then
    raise exception 'That business type does not belong to the chosen category.';
  end if;

  insert into seller_applications (business_name, district, llg, ward, primary_industry, subcategory, contact_name, phone, email,
                                   ipa_status, years_trading, staff_count, message, wants_help, consent, submitted_from)
  values (btrim(p_app->>'business_name'), (p_app->>'district')::district, nullif(p_app->>'llg',''),
          nullif(left(btrim(coalesce(p_app->>'ward','')), 120), ''),
          v_ind, v_sub, btrim(p_app->>'contact_name'), btrim(p_app->>'phone'),
          nullif(p_app->>'email',''), p_app->>'ipa_status', nullif(p_app->>'years_trading',''),
          nullif(p_app->>'staff_count',''), nullif(p_app->>'message',''),
          coalesce((p_app->>'wants_help')::boolean, false), true,
          case when p_app->>'submitted_from' = 'field' then 'field' else 'web' end)
  returning id, reference into v_id, v_ref;

  insert into application_products (application_id, name, category, subcategory, price, unit, stock, description, sort_order)
  select v_id, left(btrim(x->>'name'), 120), v_ind, v_sub,
         nullif(x->>'price','')::numeric, nullif(x->>'unit',''), nullif(x->>'stock',''),
         nullif(x->>'description',''), coalesce((x->>'sort_order')::int, 0)
  from jsonb_array_elements(p_products) x
  where length(btrim(coalesce(x->>'name',''))) > 0;

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'sort_order', sort_order) order by sort_order), '[]'::jsonb)
    into v_out from application_products where application_id = v_id;

  return jsonb_build_object('id', v_id, 'reference', v_ref, 'products', v_out);
end $function$;

-- approval copies the sub-category to the business and its products
create or replace function approve_application(app_id uuid)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
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
  insert into smes (slug, registered_name, district, llg, ward, primary_industry, subcategory, ipa_status,
                    consent, approved, approved_at, approved_by)
  values (try_slug, a.business_name, a.district, a.llg, a.ward, a.primary_industry, a.subcategory, a.ipa_status,
          a.consent, true, now(), auth.uid())
  returning id into new_sme;
  insert into sme_private (sme_id, contact_name, phone, email)
  values (new_sme, a.contact_name, a.phone, a.email)
  on conflict (sme_id) do update set contact_name = excluded.contact_name, phone = excluded.phone, email = excluded.email;
  insert into products (sme_id, name, category, subcategory, price, unit, description, stock, status)
  select new_sme, p.name, coalesce(p.category, a.primary_industry),
         case when p.category is null or p.category = a.primary_industry then coalesce(p.subcategory, a.subcategory) else p.subcategory end,
         coalesce(p.price, 0), p.unit, p.description,
         nullif(substring(coalesce(p.stock,'') from '[0-9]+'), '')::int, 'in_review'
  from application_products p where p.application_id = app_id;
  update seller_applications set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid(), created_sme_id = new_sme
  where id = app_id;
  return new_sme;
end $function$;

-- a seller changing a live listing's sub-category sends it back for review, like the category
create or replace function guard_product_status()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  if auth.uid() is null or is_division() or pg_trigger_depth() > 1 then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.badge := null; new.sort_key := 0;
    new.review_note := null; new.reviewed_at := null; new.reviewed_by := null;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'live' then
      raise exception 'Listings are published by the Division. Send it for review instead.'
        using errcode = 'check_violation';
    end if;
    if new.status not in ('draft','in_review','withdrawn') then
      raise exception 'A seller cannot set a listing to %', new.status using errcode = 'check_violation';
    end if;
  end if;

  if old.status = 'live' and new.status = 'live'
     and (new.name, new.description, new.category, new.subcategory, new.unit, new.perishable)
         is distinct from (old.name, old.description, old.category, old.subcategory, old.unit, old.perishable) then
    new.status := 'in_review';
  end if;

  new.sme_id := old.sme_id;
  new.badge := old.badge; new.sort_key := old.sort_key;
  new.review_note := old.review_note;
  new.reviewed_by := old.reviewed_by; new.reviewed_at := old.reviewed_at;
  return new;
end $function$;
