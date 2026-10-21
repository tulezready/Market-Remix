-- ============================================================
-- MaketPles ENB — editing a business's type and answers (migration 016)
-- Sellers may update their own answers (smes.details: rooms, routes,
-- opening hours...). Only the Division may change the category and
-- type (primary_industry, subcategory); for anyone else the guard
-- trigger keeps the old values. smes_subcategory_ok still checks that
-- the type belongs to the category.
-- ============================================================
grant update (primary_industry, subcategory, details) on smes to authenticated;

create or replace function guard_sme_update() returns trigger
language plpgsql security definer set search_path to 'public' as $function$
begin
  if auth.uid() is null or is_division() then return new; end if;
  new.approved := old.approved; new.approved_at := old.approved_at; new.approved_by := old.approved_by;
  new.featured := old.featured; new.owner_id := old.owner_id; new.notes := old.notes;
  new.district := old.district; new.slug := old.slug; new.consent := old.consent;
  new.primary_industry := old.primary_industry; new.subcategory := old.subcategory;   -- the Division sets the type
  return new;
end $function$;
