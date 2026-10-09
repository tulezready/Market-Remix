-- ============================================================
-- MaketPles ENB — photo moves on approval, and stock on approval
-- Applied 9 October 2026 (migration 009). Safe to re-run.
--
-- 1. The Division can read the public product-photos bucket through the
--    API. Without this, the panel's photo move on approval failed: storage
--    needs read access to check for an existing file.
-- 2. approve_application() copies stock: the application's free-text stock
--    ("40", "about 40 bunches") keeps its first number; with no number the
--    stock is left empty (not tracked) instead of 0, which shows as sold out.
-- ============================================================

do $$ begin
  create policy photos_division_read on storage.objects for select to authenticated
    using (bucket_id = 'product-photos' and is_division());
exception when duplicate_object then null; end $$;

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
  insert into products (sme_id, name, category, price, unit, description, stock, status)
  select new_sme, p.name, coalesce(p.category, a.primary_industry), coalesce(p.price, 0), p.unit, p.description,
         nullif(substring(coalesce(p.stock,'') from '[0-9]+'), '')::int, 'in_review'
  from application_products p where p.application_id = app_id;
  update seller_applications set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid(), created_sme_id = new_sme
  where id = app_id;
  return new_sme;
end $function$;
