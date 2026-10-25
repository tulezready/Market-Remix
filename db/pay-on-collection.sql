-- 021a: run on its own first (a new enum value cannot be used in the same transaction)
alter type payment_method add value if not exists 'on_collection';

-- 021b: pay on collection.
-- The buyer orders on the site and pays the seller in cash when collecting.
-- No money passes through the Division, so:
--   * the platform fee is 0 on these orders, and they never enter payouts;
--   * the seller moves the order on themselves (confirm, ready, collected
--     and paid), or cancels it if the buyer does not come;
--   * stock goes down when the seller confirms the order.
-- (021a, run first and on its own: alter type payment_method add value 'on_collection')

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
    raise exception 'Card payments are not available yet. Please pay on collection or by bank transfer.';
  end if;
  -- paying the seller in cash only works when the buyer collects from them
  if v_pay = 'on_collection' and v_fulfil <> 'sme_pickup' then
    raise exception 'Pay on collection is only for orders you collect from the business. Choose bank transfer for delivery.';
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
            v_district, v_pay, case when v_pay = 'on_collection' then 0 else s.platform_rate end, case when v_first then v_delivery else 0 end)
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

create or replace function guard_order_status() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_status order_status;
  v_steps order_status[] := array['paid','processing','ready','fulfilled']::order_status[];
  v_cash  order_status[] := array['pending_payment','processing','ready','fulfilled']::order_status[];
begin
  if auth.uid() is null or pg_trigger_depth() > 1 then
    return new;
  end if;

  new.subtotal := old.subtotal; new.delivery_fee := old.delivery_fee; new.total := old.total;
  new.platform_rate := old.platform_rate; new.platform_fee := old.platform_fee;
  new.agent_fee := old.agent_fee; new.seller_net := old.seller_net;
  new.sme_id := old.sme_id; new.basket_ref := old.basket_ref; new.order_number := old.order_number;

  if is_division() then
    if new.status is distinct from old.status then
      if in_active_payout(old.id) then
        raise exception 'This order is part of a payout. Cancel the payout before changing the order.';
      end if;
      if new.status = 'paid' and old.status = 'pending_payment' and old.payment_method <> 'on_collection'
         and coalesce(btrim(new.payment_ref), '') = '' and new.gateway_ref is null then
        raise exception 'Enter the agent receipt number or bank reference before marking the order paid.';
      end if;
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if old.payment_method = 'on_collection' then
      -- the seller is paid in cash when the buyer collects
      if not ((old.status = any(v_cash) and new.status = any(v_cash)
               and array_position(v_cash, new.status) > array_position(v_cash, old.status))
              or (new.status = 'cancelled' and old.status in ('pending_payment','processing','ready'))) then
        raise exception 'An order can only move forward: confirmed, ready, collected and paid. Cancel it if the buyer does not come.'
          using errcode = 'check_violation';
      end if;
    else
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
  end if;
  v_status := new.status;
  new := old;
  new.status := v_status;
  return new;
end $$;

create or replace function stamp_order_status() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.status is distinct from old.status then
    -- stock goes down once, when the order first moves on from waiting
    if old.status = 'pending_payment' and new.status in ('paid','processing','ready','fulfilled') then
      update products p set stock = greatest(p.stock - i.quantity, 0)
      from order_items i
      where i.order_id = new.id and p.id = i.product_id and p.stock is not null;
    end if;
    if new.status = 'paid' then
      new.paid_at := coalesce(new.paid_at, now());
      if auth.uid() is not null then new.paid_marked_by := auth.uid(); end if;
    elsif new.status = 'fulfilled' then
      new.fulfilled_at := now();
      -- paid in cash at collection
      if new.payment_method = 'on_collection' then new.paid_at := coalesce(new.paid_at, now()); end if;
    elsif new.status = 'cancelled' then
      new.cancelled_at := now();
    end if;
  end if;
  return new;
end $$;

-- what each business is owed through the Division (cash paid at collection is not)
create or replace view seller_balances with (security_invoker = true) as
with s as (select make_interval(days => payout_hold_days) as hold from platform_settings where id)
select o.sme_id,
       coalesce(sum(o.seller_net) filter (where o.status in ('paid','processing','ready')
                  or (o.status = 'fulfilled' and o.fulfilled_at > now() - s.hold)), 0) as held,
       coalesce(sum(o.seller_net) filter (where o.status = 'fulfilled' and o.fulfilled_at <= now() - s.hold
                  and not in_active_payout(o.id)), 0) as available,
       coalesce(sum(o.seller_net) filter (where exists (select 1 from payout_orders po join payouts p on p.id = po.payout_id
                  where po.order_id = o.id and p.status = 'paid')), 0) as paid_out,
       coalesce(sum(o.seller_net) filter (where exists (select 1 from payout_orders po join payouts p on p.id = po.payout_id
                  where po.order_id = o.id and p.status in ('draft','approved'))), 0) as in_payout
from orders o cross join s
where o.payment_method <> 'on_collection'
group by o.sme_id;

create or replace function prepare_payout(p_sme uuid) returns uuid
language plpgsql security definer set search_path to 'public' as $$
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
    and o.payment_method <> 'on_collection'
    and o.fulfilled_at <= now() - v_hold
    and not in_active_payout(o.id);
  if v_ids is null then raise exception 'Nothing is ready to pay this business yet.'; end if;

  insert into payouts (sme_id, amount, created_by) values (p_sme, v_amount, auth.uid())
  returning id into v_id;
  insert into payout_orders (payout_id, order_id) select v_id, unnest(v_ids);
  return v_id;
end $$;
