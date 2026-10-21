-- 019: business contact details, kept apart from the owner's own.
-- The owner's name, mobile and email (contact_name, phone, email) stay as
-- they are. Many businesses also have their own phone, email or Facebook
-- page; these are stored beside them. Both sets are private: only the
-- Division and the business's own login can read them (sme_private).

alter table seller_applications add column if not exists business_phone text;
alter table seller_applications add column if not exists business_email text;
alter table seller_applications add column if not exists business_facebook text;
alter table sme_private add column if not exists business_phone text;
alter table sme_private add column if not exists business_email text;
alter table sme_private add column if not exists business_facebook text;

create or replace function submit_application(p_app jsonb, p_products jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_id uuid; v_ref text; v_out jsonb; v_ind industry; v_sub text; v_det jsonb; v_extra text[];
begin
  if length(btrim(coalesce(p_app->>'business_name',''))) < 2 then raise exception 'Please enter the business name.'; end if;
  if length(btrim(coalesce(p_app->>'contact_name',''))) < 2 then raise exception 'Please enter a contact name.'; end if;
  if coalesce(p_app->>'phone','') !~ '^\+?[0-9 ]{7,20}$' then raise exception 'Please enter a valid phone number.'; end if;
  if coalesce(p_app->>'business_phone','') !~ '^(\+?[0-9 ]{7,20})?$' then raise exception 'Please enter a valid business phone number, or leave it empty.'; end if;
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
  -- other types the business does: known types only, not the main one, at most 4
  select coalesce(array_agg(distinct x), '{}') into v_extra
    from jsonb_array_elements_text(case when jsonb_typeof(p_app->'extra_subs') = 'array' then p_app->'extra_subs' else '[]'::jsonb end) x
   where industry_of_sub(x) is not null and x is distinct from v_sub;
  if cardinality(v_extra) > 4 then raise exception 'Please choose up to 4 other types.'; end if;

  insert into seller_applications (business_name, district, llg, ward, primary_industry, subcategory, extra_subs, details, contact_name, phone, email,
                                   business_phone, business_email, business_facebook,
                                   ipa_status, years_trading, staff_count, message, wants_help, consent, submitted_from)
  values (btrim(p_app->>'business_name'), (p_app->>'district')::district, nullif(p_app->>'llg',''),
          nullif(left(btrim(coalesce(p_app->>'ward','')), 120), ''),
          v_ind, v_sub, v_extra, v_det, btrim(p_app->>'contact_name'), btrim(p_app->>'phone'),
          nullif(p_app->>'email',''),
          nullif(btrim(coalesce(p_app->>'business_phone','')), ''), nullif(left(btrim(coalesce(p_app->>'business_email','')), 120), ''),
          nullif(left(btrim(coalesce(p_app->>'business_facebook','')), 200), ''),
          p_app->>'ipa_status', nullif(p_app->>'years_trading',''),
          nullif(p_app->>'staff_count',''), nullif(p_app->>'message',''),
          coalesce((p_app->>'wants_help')::boolean, false), true,
          case when p_app->>'submitted_from' = 'field' then 'field' else 'web' end)
  returning id, reference into v_id, v_ref;

  -- each product under its own type: the main one unless it names one of the others
  insert into application_products (application_id, name, category, subcategory, price, unit, stock, description, sort_order)
  select v_id, left(btrim(x->>'name'), 120),
         coalesce(industry_of_sub(t.sub), v_ind), coalesce(t.sub, v_sub),
         nullif(x->>'price','')::numeric, nullif(x->>'unit',''), nullif(x->>'stock',''),
         nullif(x->>'description',''), coalesce((x->>'sort_order')::int, 0)
  from jsonb_array_elements(p_products) x
  cross join lateral (select case when x->>'subcategory' = any(v_extra) then x->>'subcategory' end as sub) t
  where length(btrim(coalesce(x->>'name',''))) > 0;

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'sort_order', sort_order) order by sort_order), '[]'::jsonb)
    into v_out from application_products where application_id = v_id;

  return jsonb_build_object('id', v_id, 'reference', v_ref, 'products', v_out);
end $function$;

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
  insert into smes (slug, registered_name, district, llg, ward, primary_industry, subcategory, extra_subs, details, ipa_status,
                    consent, approved, approved_at, approved_by)
  values (try_slug, a.business_name, a.district, a.llg, a.ward, a.primary_industry, a.subcategory, coalesce(a.extra_subs, '{}'),
          coalesce(a.details, '{}'::jsonb), a.ipa_status, a.consent, true, now(), auth.uid())
  returning id into new_sme;
  insert into sme_private (sme_id, contact_name, phone, email, business_phone, business_email, business_facebook)
  values (new_sme, a.contact_name, a.phone, a.email, a.business_phone, a.business_email, a.business_facebook)
  on conflict (sme_id) do update set contact_name = excluded.contact_name, phone = excluded.phone, email = excluded.email,
    business_phone = excluded.business_phone, business_email = excluded.business_email, business_facebook = excluded.business_facebook;
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
