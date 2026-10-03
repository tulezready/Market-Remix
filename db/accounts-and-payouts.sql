-- ============================================================
-- MaketPles ENB — seller logins, order payment and payout runs
-- Run after security-and-orders.sql. Safe to re-run.
--
--   1. Orders record who marked them paid and when they were
--      fulfilled; stock goes down when an order is paid.
--   2. Sellers can only move their own paid orders forward
--      (paid → processing → ready → fulfilled), nothing else.
--   3. seller_balances counts the holding period from the
--      fulfilment date, not the last edit.
--   4. Payouts are prepared only by prepare_payout(), from
--      orders the database itself picks; a payout is approved
--      by a second person who did not verify the bank account,
--      and paid only with a bank reference.
--   5. Sellers can upload photos for their own products; a
--      photo or wording change on a live listing sends it back
--      to the Division for review.
--   6. Lookups used by the seller-logins Edge Function.
-- ============================================================


-- ============================================================
-- 1. ORDERS: payment and fulfilment stamps
-- ============================================================
alter table orders add column if not exists payment_ref    text;
alter table orders add column if not exists paid_marked_by uuid references profiles(id);
alter table orders add column if not exists fulfilled_at   timestamptz;
alter table orders add column if not exists cancelled_at   timestamptz;
comment on column orders.payment_ref is 'Agent receipt number or bank transfer reference, entered when the Division marks the order paid.';
comment on column orders.fulfilled_at is 'When the order was collected or delivered. The payout holding period counts from here.';
update orders set fulfilled_at = updated_at where status = 'fulfilled' and fulfilled_at is null;

-- true while an order belongs to a payout that has not been cancelled
create or replace function in_active_payout(p_order uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from payout_orders po join payouts p on p.id = po.payout_id
                 where po.order_id = p_order and p.status <> 'cancelled');
$$;


-- ============================================================
-- 2. WHO MAY CHANGE AN ORDER
-- ============================================================
create or replace function guard_order_status()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_status order_status;
  v_steps order_status[] := array['paid','processing','ready','fulfilled']::order_status[];
begin
  -- SQL editor / service role, and the totals recalculation run inside place_order
  if auth.uid() is null or pg_trigger_depth() > 1 then
    return new;
  end if;

  -- money is calculated by the database; nobody edits it through the API
  new.subtotal := old.subtotal; new.delivery_fee := old.delivery_fee; new.total := old.total;
  new.platform_rate := old.platform_rate; new.platform_fee := old.platform_fee;
  new.agent_fee := old.agent_fee; new.seller_net := old.seller_net;
  new.sme_id := old.sme_id; new.basket_ref := old.basket_ref; new.order_number := old.order_number;

  if is_division() then
    if new.status is distinct from old.status then
      if in_active_payout(old.id) then
        raise exception 'This order is part of a payout. Cancel the payout before changing the order.';
      end if;
      if new.status = 'paid' and old.status = 'pending_payment'
         and coalesce(btrim(new.payment_ref), '') = '' and new.gateway_ref is null then
        raise exception 'Enter the agent receipt number or bank reference before marking the order paid.';
      end if;
    end if;
    return new;
  end if;

  -- a seller: forward through fulfilment only, and only the status changes
  if new.status is distinct from old.status then
    if old.status = 'pending_payment' then
      raise exception 'This order is not paid yet. The Division confirms payment.'
        using errcode = 'check_violation';
    end if;
    if not (old.status = any(v_steps) and new.status = any(v_steps)
            and array_position(v_steps, new.status) > array_position(v_steps, old.status)) then
      raise exception 'An order can only move forward: paid, preparing, ready, collected.'
        using errcode = 'check_violation';
    end if;
  end if;
  v_status := new.status;
  new := old;
  new.status := v_status;
  return new;
end $$;

-- runs after the guard (triggers fire in name order)
create or replace function stamp_order_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'paid' then
      new.paid_at := coalesce(new.paid_at, now());
      if auth.uid() is not null then new.paid_marked_by := auth.uid(); end if;
      if old.status = 'pending_payment' then
        update products p set stock = greatest(p.stock - i.quantity, 0)
        from order_items i
        where i.order_id = new.id and p.id = i.product_id and p.stock is not null;
      end if;
    elsif new.status = 'fulfilled' then
      new.fulfilled_at := now();
    elsif new.status = 'cancelled' then
      new.cancelled_at := now();
    end if;
  end if;
  return new;
end $$;
create or replace trigger trg_stamp_order before update on orders
  for each row execute function stamp_order_status();


-- ============================================================
-- 3. BALANCES: hold counted from fulfilment
-- ============================================================
create or replace view seller_balances with (security_invoker = true) as
with s as (select make_interval(days => payout_hold_days) as hold from platform_settings where id)
select o.sme_id,
       coalesce(sum(o.seller_net) filter (where o.status in ('paid','processing','ready')
                  or (o.status = 'fulfilled' and o.fulfilled_at > now() - s.hold)), 0) as held,
       coalesce(sum(o.seller_net) filter (where o.status = 'fulfilled'
                  and o.fulfilled_at <= now() - s.hold
                  and not in_active_payout(o.id)), 0) as available,
       coalesce(sum(o.seller_net) filter (where exists (select 1 from payout_orders po join payouts p on p.id = po.payout_id
                                                       where po.order_id = o.id and p.status = 'paid')), 0) as paid_out,
       coalesce(sum(o.seller_net) filter (where exists (select 1 from payout_orders po join payouts p on p.id = po.payout_id
                                                       where po.order_id = o.id and p.status in ('draft','approved'))), 0) as in_payout
from orders o cross join s
group by o.sme_id;
grant select on seller_balances to authenticated;


-- ============================================================
-- 4. PAYOUTS
-- ============================================================
-- payouts and their order lists are created only by prepare_payout()
revoke insert, delete on payouts from anon, authenticated;
revoke insert, update, delete on payout_orders from anon, authenticated;
revoke all on payouts, payout_orders from anon;

create or replace function prepare_payout(p_sme uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_hold interval;
  v_ids uuid[];
  v_amount numeric(10,2);
  v_id uuid;
begin
  if not is_division() then raise exception 'Only Division staff can prepare payouts.'; end if;
  select make_interval(days => payout_hold_days) into v_hold from platform_settings where id;

  perform 1 from orders where sme_id = p_sme for update;
  select array_agg(o.id), sum(o.seller_net) into v_ids, v_amount
  from orders o
  where o.sme_id = p_sme and o.status = 'fulfilled'
    and o.fulfilled_at <= now() - v_hold
    and not in_active_payout(o.id);
  if v_ids is null then raise exception 'Nothing is ready to pay this business yet.'; end if;

  insert into payouts (sme_id, amount, created_by) values (p_sme, v_amount, auth.uid())
  returning id into v_id;
  insert into payout_orders (payout_id, order_id) select v_id, unnest(v_ids);
  return v_id;
end $$;
revoke execute on function prepare_payout(uuid) from public, anon;
grant execute on function prepare_payout(uuid) to authenticated;

create or replace function guard_payout()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_verifier uuid;
begin
  if auth.uid() is null then return new; end if;

  new.sme_id := old.sme_id; new.amount := old.amount; new.period_end := old.period_end;
  new.created_by := old.created_by; new.created_at := old.created_at;
  new.approved_by := old.approved_by; new.approved_at := old.approved_at;
  new.paid_by := old.paid_by; new.paid_at := old.paid_at;

  if old.status in ('paid','cancelled') then
    if new.status is distinct from old.status or new.bank_reference is distinct from old.bank_reference then
      raise exception 'This payout is closed and cannot be changed.';
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'approved' then
      if old.status <> 'draft' then raise exception 'Only a draft payout can be approved.'; end if;
      if auth.uid() = old.created_by then
        raise exception 'A payout must be approved by someone other than the person who prepared it.';
      end if;
      select bank_verified_by into v_verifier from sme_private where sme_id = old.sme_id;
      if v_verifier is not null and v_verifier = auth.uid() then
        raise exception 'You verified this business''s bank account, so someone else must approve its payout.';
      end if;
      new.approved_by := auth.uid(); new.approved_at := now();
    elsif new.status = 'paid' then
      if old.status <> 'approved' then raise exception 'A payout must be approved before it is paid.'; end if;
      if not exists (select 1 from sme_private where sme_id = new.sme_id and bank_verified) then
        raise exception 'This business''s bank account has not been verified.';
      end if;
      if coalesce(btrim(new.bank_reference), '') = '' then
        raise exception 'Enter the bank transfer reference.';
      end if;
      new.paid_by := auth.uid(); new.paid_at := now();
    elsif new.status = 'cancelled' then
      delete from payout_orders where payout_id = old.id;   -- the orders become payable again
    else
      raise exception 'A payout cannot go back to %.', new.status;
    end if;
  end if;
  return new;
end $$;


-- ============================================================
-- 5. LISTINGS AND PHOTOS
-- ============================================================
create or replace function guard_product_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or is_division() or pg_trigger_depth() > 1 then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- merchandising and review fields belong to the Division
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

  -- price and stock change straight away; wording changes are checked again
  if old.status = 'live' and new.status = 'live'
     and (new.name, new.description, new.category, new.unit, new.perishable)
         is distinct from (old.name, old.description, old.category, old.unit, old.perishable) then
    new.status := 'in_review';
  end if;

  new.sme_id := old.sme_id;
  new.badge := old.badge; new.sort_key := old.sort_key;
  new.review_note := old.review_note;
  new.reviewed_by := old.reviewed_by; new.reviewed_at := old.reviewed_at;
  return new;
end $$;
create or replace trigger trg_guard_product_status before insert or update on products
  for each row execute function guard_product_status();

-- a seller adding or removing a photo on a live listing sends it back for review
create or replace function review_photo_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_product uuid := coalesce(new.product_id, old.product_id);
begin
  if auth.uid() is not null and not is_division() then
    update products set status = 'in_review' where id = v_product and status = 'live';
  end if;
  return null;
end $$;
create or replace trigger trg_review_photo_change after insert or delete on product_images
  for each row execute function review_photo_change();

-- sellers upload to product-photos/sme/<their business id>/...
create or replace function owns_sme_folder(p_name text)
returns boolean language sql stable security definer set search_path = public as $$
  select (storage.foldername(p_name))[1] = 'sme'
     and exists (select 1 from smes where id::text = (storage.foldername(p_name))[2] and owner_id = auth.uid());
$$;
do $$ begin
  create policy photos_seller_write on storage.objects for insert to authenticated
    with check (bucket_id = 'product-photos' and owns_sme_folder(name));
exception when duplicate_object then null; end $$;
do $$ begin
  create policy photos_seller_delete on storage.objects for delete to authenticated
    using (bucket_id = 'product-photos' and owns_sme_folder(name));
exception when duplicate_object then null; end $$;


-- ============================================================
-- 6. SELLER LOGINS (used by the seller-logins Edge Function,
--    which runs with the secret key — never callable by users)
-- ============================================================
create or replace function auth_user_by_email(p_email text)
returns table (id uuid, email text, last_sign_in_at timestamptz)
language sql stable security definer set search_path = public, auth as $$
  select u.id, u.email::text, u.last_sign_in_at from auth.users u where lower(u.email) = lower(btrim(p_email));
$$;
create or replace function seller_logins()
returns table (sme_id uuid, email text, last_sign_in_at timestamptz)
language sql stable security definer set search_path = public, auth as $$
  select s.id, u.email::text, u.last_sign_in_at from smes s join auth.users u on u.id = s.owner_id;
$$;
revoke execute on function auth_user_by_email(text) from public, anon, authenticated;
revoke execute on function seller_logins() from public, anon, authenticated;
grant execute on function auth_user_by_email(text) to service_role;
grant execute on function seller_logins() to service_role;

-- helper functions are not for calling directly through the API
revoke execute on function in_active_payout(uuid) from public, anon;
revoke execute on function owns_sme_folder(text) from public, anon;
revoke execute on function stamp_order_status() from public, anon, authenticated;
revoke execute on function review_photo_change() from public, anon, authenticated;

-- the price log is written by a trigger; sellers have no insert right on
-- price_history, so the trigger must run as its owner
alter function log_price_change() security definer;
revoke execute on function log_price_change() from public, anon, authenticated;

-- every business has a private-details row, so its seller can add contact and bank details
insert into sme_private (sme_id) select id from smes on conflict (sme_id) do nothing;
create or replace function ensure_sme_private()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into sme_private (sme_id) values (new.id) on conflict (sme_id) do nothing;
  return null;
end $$;
create or replace trigger trg_ensure_sme_private after insert on smes
  for each row execute function ensure_sme_private();
revoke execute on function ensure_sme_private() from public, anon, authenticated;

-- approving an application fills in the row the trigger above created
CREATE OR REPLACE FUNCTION public.approve_application(app_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  values (new_sme, a.contact_name, a.phone, a.email)
  on conflict (sme_id) do update set contact_name = excluded.contact_name, phone = excluded.phone, email = excluded.email;
  insert into products (sme_id, name, category, price, unit, description, status)
  select new_sme, p.name, coalesce(p.category, a.primary_industry), coalesce(p.price, 0), p.unit, p.description, 'in_review'
  from application_products p where p.application_id = app_id;
  update seller_applications set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid(), created_sme_id = new_sme
  where id = app_id;
  return new_sme;
end $function$;
