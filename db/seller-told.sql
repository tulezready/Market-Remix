-- 022: who told the seller about a new order, and when.
-- Until automatic SMS is set up, the Division panel lists each new order
-- with one-tap SMS / WhatsApp / call buttons; pressing one records it here
-- so two staff do not both send it. Only the Division writes these (the
-- order guard keeps every other column of a seller's update unchanged).
alter table orders add column if not exists seller_told_at timestamptz;
alter table orders add column if not exists seller_told_by uuid references auth.users(id);
