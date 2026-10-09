-- ============================================================
-- MaketPles ENB — LLG chosen from a list, ward or village separate
-- Applied 9 October 2026 (migration 011). Safe to re-run.
--   * seller_applications.ward and smes.ward (ward or village in the LLG)
--   * public_smes exposes ward (appended last, so the view keeps its columns)
--   * submit_application() saves ward; approve_application() copies it
-- The register form now offers the 18 ENB LLGs as a list for the chosen
-- district (or "Not sure", saved as empty for the Division to check).
-- ============================================================
alter table seller_applications add column if not exists ward text;
alter table smes add column if not exists ward text;
comment on column smes.llg is 'Local-level Government, chosen from the list of ENB LLGs.';
comment on column smes.ward is 'Ward or village within the LLG.';
grant select (ward) on smes to anon, authenticated;
grant insert (ward), update (ward) on smes to authenticated;

create or replace view public_smes with (security_invoker = true) as
select s.id, s.slug, coalesce(s.trading_name, s.registered_name) as name, s.registered_name,
       s.district, s.llg, s.primary_industry, s.secondary_industry, s.description,
       s.photo_ref, s.hero_photo_ref, s.featured, s.is_sample, s.ward
from smes s
where s.approved = true;

-- submit_application() and approve_application(): as in db/photo-moves-and-stock.sql and
-- security-and-orders.sql, with `ward` added to the insert column lists:
--   seller_applications (..., llg, ward, ...) values (..., nullif(left(btrim(coalesce(p_app->>'ward','')), 120), ''), ...)
--   smes (..., llg, ward, ...) values (..., a.llg, a.ward, ...)
-- The full current definitions can be read from the database with
--   select pg_get_functiondef('submit_application'::regproc);
