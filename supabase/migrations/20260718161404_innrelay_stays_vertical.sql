-- InnRelay Stays: additive private-beta backend.
-- This migration does not replace the working InnRelay Hotels RPC or policies.

create table if not exists private.stays_issue_categories (
  category_key text primary key,
  category_label text not null check (char_length(category_label) between 2 and 140),
  default_department_code text not null,
  emergency boolean not null default false,
  sort_order integer not null default 0,
  active boolean not null default true
);

revoke all on table private.stays_issue_categories from public, anon, authenticated;

insert into private.stays_issue_categories
  (category_key, category_label, default_department_code, emergency, sort_order)
values
  ('str-checkin-access', 'Check-in & arrival', 'guest-support', false, 10),
  ('str-locks-keys-security', 'Keys, lockbox & smart lock', 'guest-support', false, 20),
  ('str-cleaning-maintenance', 'Cleaning & property condition', 'turnover-housekeeping', false, 30),
  ('str-essentials-supplies', 'Missing essentials & supplies', 'turnover-housekeeping', false, 40),
  ('str-bedroom-linen-comfort', 'Bedroom, bedding & towels', 'turnover-housekeeping', false, 50),
  ('str-bathroom-water', 'Bathroom, plumbing & hot water', 'maintenance', false, 60),
  ('str-kitchen-appliances', 'Kitchen & appliances', 'maintenance', false, 70),
  ('str-heating-cooling-air', 'Heating, cooling & air quality', 'maintenance', false, 80),
  ('str-wifi-tv-technology', 'Wi-Fi, TV & smart-home', 'guest-support', false, 90),
  ('str-electricity-lighting', 'Electricity, lighting & charging', 'maintenance', false, 100),
  ('str-noise-neighbours-rules', 'Noise, neighbours & house rules', 'guest-support', false, 110),
  ('str-parking-transport', 'Parking & local access', 'guest-support', false, 120),
  ('str-outdoor-leisure', 'Balcony, garden, pool & leisure', 'maintenance', false, 130),
  ('str-damage-pests-maintenance', 'Damage, pests & maintenance', 'maintenance', false, 140),
  ('str-checkout-luggage', 'Checkout, luggage & departure', 'guest-support', false, 150),
  ('str-safety-alarms', 'Safety, alarms & urgent concerns', 'safety-escalation', true, 160),
  ('str-host-contact-support', 'Host contact, service & complaint', 'guest-support', false, 170)
on conflict (category_key) do update set
  category_label = excluded.category_label,
  default_department_code = excluded.default_department_code,
  emergency = excluded.emergency,
  sort_order = excluded.sort_order,
  active = excluded.active;

create index if not exists guest_reports_duplicate_of_idx
  on public.guest_reports (duplicate_of)
  where duplicate_of is not null;

create or replace function public.create_stays_workspace(p_payload jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  new_property_id uuid;
  safe_name text := left(trim(coalesce(p_payload->>'name', '')), 120);
  safe_slug text := lower(left(trim(coalesce(p_payload->>'slug', '')), 80));
  safe_address text := nullif(left(trim(coalesce(p_payload->>'address', '')), 300), '');
  safe_contact text := nullif(left(trim(coalesce(p_payload->>'guest_contact', '')), 120), '');
  safe_colour text := coalesce(nullif(p_payload->>'brand_colour', ''), '#2f8068');
begin
  if current_user_id is null
     or coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'true' then
    raise exception 'Sign in with Google before registering an InnRelay Stays workspace.';
  end if;

  if char_length(safe_name) < 2 then
    raise exception 'Enter a property or listing name.';
  end if;

  if safe_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Choose a public URL name using letters, numbers and hyphens.';
  end if;

  if safe_colour !~ '^#[0-9A-Fa-f]{6}$' then safe_colour := '#2f8068'; end if;

  insert into public.properties
    (name, slug, created_by, property_type, address, reception_phone,
     brand_colour, timezone, data_retention_days, active)
  values
    (safe_name, safe_slug, current_user_id, 'short_term_rental', safe_address,
     safe_contact, safe_colour, 'Europe/London', 90, true)
  returning id into new_property_id;

  insert into public.property_departments
    (property_id, name, code, response_target_minutes, escalation_minutes)
  values
    (new_property_id, 'Guest Support', 'guest-support', 5, 15),
    (new_property_id, 'Turnover & Housekeeping', 'turnover-housekeeping', 15, 30),
    (new_property_id, 'Maintenance', 'maintenance', 15, 30),
    (new_property_id, 'Safety & Escalation', 'safety-escalation', 3, 5);

  insert into public.property_locations
    (property_id, department_id, name, code, location_type, allows_guest_correction, sort_order)
  select new_property_id, department.id, seed.name, seed.code, seed.location_type, true, seed.sort_order
  from (values
    ('Entrance / check-in', 'entrance', 'entrance', 'guest-support', 10),
    ('Living area', 'living-area', 'living', 'guest-support', 20),
    ('Kitchen', 'kitchen', 'kitchen', 'maintenance', 30),
    ('Bathroom', 'bathroom', 'bathroom', 'maintenance', 40),
    ('Bedroom', 'bedroom', 'bedroom', 'turnover-housekeeping', 50),
    ('Outdoor area', 'outdoor-area', 'outdoor', 'maintenance', 60),
    ('Parking', 'parking', 'parking', 'guest-support', 70),
    ('Whole property', 'whole-property', 'whole_property', 'safety-escalation', 80)
  ) as seed(name, code, location_type, department_code, sort_order)
  join public.property_departments department
    on department.property_id = new_property_id
   and department.code = seed.department_code;

  insert into public.department_routes (property_id, category_key, department_id)
  select new_property_id, category.category_key, department.id
  from private.stays_issue_categories category
  join public.property_departments department
    on department.property_id = new_property_id
   and department.code = category.default_department_code
  where category.active = true;

  return new_property_id;
end;
$$;

revoke all on function public.create_stays_workspace(jsonb) from public, anon;
grant execute on function public.create_stays_workspace(jsonb) to authenticated;

create or replace function public.create_stays_area(p_property_id uuid, p_payload jsonb)
returns public.property_locations
language plpgsql
security invoker
set search_path = ''
as $$
declare
  allowed_types constant text[] := array[
    'entrance','living','kitchen','bathroom','bedroom','dining','laundry',
    'workspace','outdoor','parking','pool_hot_tub','shared_area','whole_property','other'
  ];
  safe_name text := left(trim(coalesce(p_payload->>'name', '')), 100);
  safe_code text := lower(left(trim(coalesce(p_payload->>'code', '')), 80));
  safe_type text := coalesce(nullif(p_payload->>'location_type', ''), 'other');
  safe_department_id uuid := nullif(p_payload->>'department_id', '')::uuid;
  safe_sort_order integer := coalesce((p_payload->>'sort_order')::integer, 0);
  created_area public.property_locations%rowtype;
begin
  if not private.is_property_manager(p_property_id) then
    raise exception 'Only a Stay owner or manager can add areas.';
  end if;

  if not exists (
    select 1 from public.properties property
    where property.id = p_property_id
      and property.property_type = 'short_term_rental'
      and property.active = true
  ) then
    raise exception 'This action is available only in InnRelay Stays.';
  end if;

  if char_length(safe_name) < 1 or char_length(safe_code) < 1 then
    raise exception 'Enter an area name and code.';
  end if;

  if not (safe_type = any(allowed_types)) then
    raise exception 'Choose a valid InnRelay Stays area type.';
  end if;

  if safe_department_id is not null and not exists (
    select 1 from public.property_departments department
    where department.id = safe_department_id
      and department.property_id = p_property_id
      and department.active = true
  ) then
    raise exception 'Choose an active host team for this Stay.';
  end if;

  insert into public.property_locations
    (property_id, department_id, name, code, location_type, allows_guest_correction, sort_order)
  values
    (p_property_id, safe_department_id, safe_name, safe_code, safe_type, true, safe_sort_order)
  returning * into created_area;

  return created_area;
end;
$$;

revoke all on function public.create_stays_area(uuid, jsonb) from public, anon;
grant execute on function public.create_stays_area(uuid, jsonb) to authenticated;

create or replace function public.submit_stays_guest_report(p_payload jsonb)
returns public.guest_reports
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_property_id uuid := nullif(p_payload->>'property_id', '')::uuid;
  target_location_id uuid := nullif(p_payload->>'location_id', '')::uuid;
  supplied_category text := left(trim(coalesce(p_payload->>'category_key', '')), 100);
  canonical_category private.stays_issue_categories%rowtype;
  selected_area public.property_locations%rowtype;
  safe_payload jsonb;
begin
  if (select auth.uid()) is null
     or coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true' then
    raise exception 'Start a secure Stays QR session before sending a request.';
  end if;

  select category.* into canonical_category
  from private.stays_issue_categories category
  where category.category_key = supplied_category
    and category.active = true;

  if canonical_category.category_key is null then
    raise exception 'Choose a current InnRelay Stays request category.';
  end if;

  select location.* into selected_area
  from public.property_locations location
  join public.properties property
    on property.id = location.property_id
   and property.property_type = 'short_term_rental'
   and property.active = true
  where location.id = target_location_id
    and location.property_id = target_property_id
    and location.active = true
    and location.location_type in (
      'entrance','living','kitchen','bathroom','bedroom','dining','laundry',
      'workspace','outdoor','parking','pool_hot_tub','shared_area','whole_property','other'
    );

  if selected_area.id is null then
    raise exception 'Choose an active area inside this InnRelay Stay.';
  end if;

  if not private.has_guest_portal_access(target_property_id, target_location_id) then
    raise exception 'This Stays QR session is not valid for the selected property area.';
  end if;

  safe_payload := p_payload
    || jsonb_build_object(
      'property_id', target_property_id,
      'location_id', target_location_id,
      'category_key', canonical_category.category_key,
      'category_label', canonical_category.category_label,
      'issue_code', canonical_category.category_key || ':' ||
        left(regexp_replace(lower(coalesce(p_payload->>'title', 'request')), '[^a-z0-9]+', '-', 'g'), 80),
      'urgency', case when p_payload->>'urgency' in ('normal','soon','urgent') then p_payload->>'urgency' else 'normal' end,
      'contact_preference', 'app',
      'source', 'guest'
    );

  return public.submit_guest_report(safe_payload);
end;
$$;

revoke all on function public.submit_stays_guest_report(jsonb) from public, anon;
grant execute on function public.submit_stays_guest_report(jsonb) to authenticated;

