-- ============================================================
--  MaketPles ENB — Public submission support
--  Run AFTER db/schema.sql, in the same Supabase project.
-- ------------------------------------------------------------
--  Adds what a business needs to submit itself through a link:
--  its products, its photographs, and the storage rules that
--  let it upload without an account.
-- ============================================================


-- ============================================================
-- 1. EXTRA COLUMNS ON seller_applications
-- ============================================================

alter table seller_applications
  add column if not exists llg              text,
  add column if not exists years_trading    text,
  add column if not exists staff_count      text,
  add column if not exists wants_help       boolean not null default false,
  add column if not exists consent          boolean not null default false,
  add column if not exists reference        text unique,
  add column if not exists submitted_from   text default 'web';

comment on column seller_applications.reference is
  'Short code given to the applicant, e.g. ENB-A4821. They quote it when they call.';
comment on column seller_applications.submitted_from is
  'web = the business filled it in themselves. field = an officer entered it.';


-- ---------- readable reference code ----------
create sequence if not exists application_seq start 1000;

create or replace function set_application_reference()
returns trigger language plpgsql as $$
begin
  if new.reference is null or new.reference = '' then
    new.reference := 'ENB-A' || nextval('application_seq')::text;
  end if;
  return new;
end $$;

drop trigger if exists trg_application_reference on seller_applications;
create trigger trg_application_reference
  before insert on seller_applications
  for each row execute function set_application_reference();


-- ============================================================
-- 2. PRODUCTS SUBMITTED WITH AN APPLICATION
--    Kept separate from `products` until the business is
--    approved. Nothing here is ever public.
-- ============================================================

create table if not exists application_products (
  id             uuid primary key default gen_random_uuid(),
  application_id uuid not null references seller_applications(id) on delete cascade,
  name           text not null,
  category       industry,
  price          numeric(10,2) check (price is null or price >= 0),
  unit           text,
  stock          text,
  description    text,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now()
);

create index if not exists idx_app_products on application_products(application_id);


-- ============================================================
-- 3. PHOTOGRAPHS SUBMITTED WITH AN APPLICATION
--    The file itself lives in storage; this row records what
--    it is of, so the Division can sort them later.
-- ============================================================

do $$ begin
  create type photo_kind as enum ('business', 'hero', 'product');
exception when duplicate_object then null; end $$;

create table if not exists application_photos (
  id             uuid primary key default gen_random_uuid(),
  application_id uuid not null references seller_applications(id) on delete cascade,
  product_id     uuid references application_products(id) on delete cascade,
  kind           photo_kind not null default 'product',
  storage_path   text not null,
  original_name  text,
  bytes          integer,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now()
);

create index if not exists idx_app_photos on application_photos(application_id);


-- ============================================================
-- 4. ROW LEVEL SECURITY
--    Anyone may submit. Only the Division may read.
--    An applicant cannot see anyone else's application —
--    including their own, once submitted.
-- ============================================================

alter table application_products enable row level security;
alter table application_photos   enable row level security;

drop policy if exists app_products_insert on application_products;
create policy app_products_insert on application_products
  for insert with check (
    exists (
      select 1 from seller_applications a
      where a.id = application_products.application_id
        and a.status = 'pending'
        and a.created_at > now() - interval '1 hour'
    )
  );

drop policy if exists app_products_division on application_products;
create policy app_products_division on application_products
  for all using (is_division()) with check (is_division());

drop policy if exists app_photos_insert on application_photos;
create policy app_photos_insert on application_photos
  for insert with check (
    exists (
      select 1 from seller_applications a
      where a.id = application_photos.application_id
        and a.status = 'pending'
        and a.created_at > now() - interval '1 hour'
    )
  );

drop policy if exists app_photos_division on application_photos;
create policy app_photos_division on application_photos
  for all using (is_division()) with check (is_division());

-- The one-hour window means a submission link cannot be reused
-- days later to append rows to someone else's application.


-- ============================================================
-- 5. STORAGE
--    Create the bucket in the dashboard first:
--      Storage → New bucket → name: applications → PRIVATE
--    Then run the policies below.
-- ============================================================

-- anyone may upload into the applications bucket
drop policy if exists app_upload on storage.objects;
create policy app_upload on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'applications');

-- only the Division may look at what was uploaded
drop policy if exists app_read on storage.objects;
create policy app_read on storage.objects
  for select to authenticated
  using (bucket_id = 'applications' and is_division());

drop policy if exists app_manage on storage.objects;
create policy app_manage on storage.objects
  for all to authenticated
  using (bucket_id = 'applications' and is_division())
  with check (bucket_id = 'applications' and is_division());

-- NOTE ON ABUSE
-- Anonymous upload is what makes a public link work, but it is
-- also open to misuse. In the bucket settings set a file size
-- limit (2 MB is ample once the browser has shrunk the image)
-- and restrict allowed MIME types to image/jpeg and image/png.
-- Review the queue regularly and delete anything unrelated.


-- ============================================================
-- 6. VIEW: the Division's application queue
-- ============================================================

-- security_invoker keeps row level security in force. Without it
-- this view would expose every applicant's name, phone number and
-- email address to anyone holding the public key.
create or replace view application_queue with (security_invoker = true) as
select
  a.id,
  a.reference,
  a.business_name,
  a.district,
  a.primary_industry,
  a.contact_name,
  a.phone,
  a.email,
  a.ipa_status,
  a.wants_help,
  a.consent,
  a.status,
  a.submitted_from,
  a.created_at,
  (select count(*) from application_products p where p.application_id = a.id) as product_count,
  (select count(*) from application_photos  ph where ph.application_id = a.id) as photo_count
from seller_applications a
order by a.created_at desc;


-- ============================================================
-- 7. APPROVING AN APPLICATION
--    Copies the application into the live tables in one step.
--    Division only.
-- ============================================================

create or replace function approve_application(app_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  a  seller_applications%rowtype;
  new_sme uuid;
  base_slug text;
  try_slug  text;
  n int := 1;
begin
  if not is_division() then
    raise exception 'Only Division staff may approve applications';
  end if;

  select * into a from seller_applications where id = app_id;
  if not found then raise exception 'No such application'; end if;
  if a.status = 'approved' then raise exception 'Already approved'; end if;

  -- a readable, unique slug for the stall page
  base_slug := regexp_replace(lower(a.business_name), '[^a-z0-9]+', '', 'g');
  base_slug := left(coalesce(nullif(base_slug,''), 'sme'), 16);
  try_slug := base_slug;
  while exists (select 1 from smes where slug = try_slug) loop
    n := n + 1;
    try_slug := left(base_slug, 14) || n::text;
  end loop;

  insert into smes (slug, registered_name, district, llg, primary_industry,
                    ipa_status, contact_name, phone, email, consent,
                    approved, approved_at, approved_by)
  values (try_slug, a.business_name, a.district, a.llg, a.primary_industry,
          a.ipa_status, a.contact_name, a.phone, a.email, a.consent,
          true, now(), auth.uid())
  returning id into new_sme;

  -- products come across as drafts, for the Division to review
  insert into products (sme_id, name, category, price, unit, description, status)
  select new_sme, p.name, coalesce(p.category, a.primary_industry),
         coalesce(p.price, 0), p.unit, p.description, 'in_review'
  from application_products p
  where p.application_id = app_id;

  update seller_applications
     set status = 'approved', reviewed_at = now(),
         reviewed_by = auth.uid(), created_sme_id = new_sme
   where id = app_id;

  return new_sme;
end $$;

comment on function approve_application is
  'Turns an application into a live business and draft listings. Photographs are moved by the Division panel afterwards.';


-- ============================================================
--  END
--  Reminder: create the `applications` storage bucket (private)
--  before anyone submits, or uploads will fail.
-- ============================================================
