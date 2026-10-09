-- ============================================================
-- MaketPles ENB — delete a business (Division admins only)
-- Paste into Supabase → SQL Editor → Run. Safe to re-run.
--
-- Used by the Division panel's "Delete permanently" button. Refuses any
-- business with orders or payouts (those records must be kept — use
-- "Remove from site" instead). Deletes the business with its products,
-- product images and private details, and its application with that
-- application's products and photo records. Returns the photo file paths
-- so the panel can remove the files through the Storage API.
-- ============================================================
create or replace function delete_sme(p_sme uuid)
returns jsonb language plpgsql security definer set search_path = public, storage as $$
declare
  v_slug text;
  v_product_photos text[];
  v_app_photos text[];
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'division_admin') then
    raise exception 'Only a Division admin can delete a business.';
  end if;
  select slug into v_slug from smes where id = p_sme;
  if v_slug is null then raise exception 'Business not found.'; end if;
  if exists (select 1 from orders where sme_id = p_sme) or exists (select 1 from payouts where sme_id = p_sme) then
    raise exception 'This business has orders or payouts, which must be kept. Use "Remove from site" instead.';
  end if;

  select coalesce(array_agg(name), '{}') into v_product_photos from storage.objects
   where bucket_id = 'product-photos' and (name like v_slug || '/%' or name like 'sme/' || p_sme::text || '/%');
  select coalesce(array_agg(ph.storage_path), '{}') into v_app_photos
    from application_photos ph join seller_applications a on a.id = ph.application_id
   where a.created_sme_id = p_sme;

  delete from seller_applications where created_sme_id = p_sme;
  delete from smes where id = p_sme;

  return jsonb_build_object('product_photos', to_jsonb(v_product_photos), 'application_photos', to_jsonb(v_app_photos));
end $$;
revoke execute on function delete_sme(uuid) from public, anon;
grant execute on function delete_sme(uuid) to authenticated;
