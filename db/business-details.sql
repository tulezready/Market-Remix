-- ============================================================
-- MaketPles ENB — questions for each type of business (migration 014)
-- The register form asks different questions for a guest house, a PMV,
-- a fishing business and so on (the sets are in categories.js). The
-- answers are kept together as one JSON object, e.g.
--   {"rooms": "4", "meals": "Breakfast included", "facilities": ["Power","Shower"]}
-- on the application, and copied to the business when it is approved.
-- ============================================================
alter table seller_applications add column if not exists details jsonb not null default '{}'::jsonb;
alter table smes                add column if not exists details jsonb not null default '{}'::jsonb;
alter table seller_applications add constraint apps_details_object check (jsonb_typeof(details) = 'object' and length(details::text) < 8000) not valid;
alter table smes                add constraint smes_details_object check (jsonb_typeof(details) = 'object' and length(details::text) < 8000) not valid;
alter table seller_applications validate constraint apps_details_object;
alter table smes                validate constraint smes_details_object;
-- smes has column-level grants: the Division's insert may set it; it is not public
grant insert (details), select (details) on smes to authenticated;

-- submit: save the answers (only an object, size-checked by the constraint)
create or replace function submit_application(p_app jsonb, p_products jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_id uuid; v_ref text; v_out jsonb; v_ind industry; v_sub text; v_det jsonb;
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
  v_det := case when jsonb_typeof(p_app->'details') = 'object' then p_app->'details' else '{}'::jsonb end;
  if length(v_det::text) >= 8000 then raise exception 'Too much detail — please shorten your answers.'; end if;

  insert into seller_applications (business_name, district, llg, ward, primary_industry, subcategory, details, contact_name, phone, email,
                                   ipa_status, years_trading, staff_count, message, wants_help, consent, submitted_from)
  values (btrim(p_app->>'business_name'), (p_app->>'district')::district, nullif(p_app->>'llg',''),
          nullif(left(btrim(coalesce(p_app->>'ward','')), 120), ''),
          v_ind, v_sub, v_det, btrim(p_app->>'contact_name'), btrim(p_app->>'phone'),
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

-- approve: the answers go to the business too
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
  insert into smes (slug, registered_name, district, llg, ward, primary_industry, subcategory, details, ipa_status,
                    consent, approved, approved_at, approved_by)
  values (try_slug, a.business_name, a.district, a.llg, a.ward, a.primary_industry, a.subcategory, coalesce(a.details, '{}'::jsonb), a.ipa_status,
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
