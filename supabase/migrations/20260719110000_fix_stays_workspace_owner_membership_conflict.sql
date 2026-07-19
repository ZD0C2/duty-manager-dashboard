-- The create_property_owner_membership trigger on public.properties already
-- inserts the owner's property_staff row (with ON CONFLICT DO NOTHING)
-- immediately after the properties insert below. create_stays_workspace's
-- own explicit "bootstrap the owner" insert then collided with that
-- trigger's row every single time (23505 on property_staff_pkey), rolling
-- back the whole workspace and silently discarding every Stays
-- registration attempt.
create or replace function public.create_stays_workspace(p_payload jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  new_property_id uuid := gen_random_uuid();
  safe_name text := left(trim(coalesce(p_payload->>'name', '')), 120);
  safe_slug text := lower(left(trim(coalesce(p_payload->>'slug', '')), 80));
  safe_address text := nullif(left(trim(coalesce(p_payload->>'address', '')), 300), '');
  safe_contact text := nullif(left(trim(coalesce(p_payload->>'guest_contact', '')), 120), '');
  safe_colour text := coalesce(nullif(p_payload->>'brand_colour', ''), '#2f8068');
  safe_display_name text := left(coalesce(
    nullif(trim((select auth.jwt()->'user_metadata'->>'full_name')), ''),
    nullif(trim((select auth.jwt()->'user_metadata'->>'name')), ''),
    nullif(split_part(coalesce((select auth.jwt()->>'email'), ''), '@', 1), ''),
    'Stay owner'
  ), 100);
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

  -- Supply the UUID instead of using INSERT ... RETURNING. This lets the
  -- invoker stay inside RLS while the owner membership is still being built.
  insert into public.properties
    (id, name, slug, created_by, property_type, address, reception_phone,
     brand_colour, timezone, data_retention_days, active)
  values
    (new_property_id, safe_name, safe_slug, current_user_id, 'short_term_rental',
     safe_address, safe_contact, safe_colour, 'Europe/London', 90, true);

  -- The AFTER INSERT trigger on public.properties already created this row;
  -- this keeps the explicit safe_display_name as a defensive fallback only.
  insert into public.property_staff
    (property_id, user_id, display_name, role, active)
  values
    (new_property_id, current_user_id, safe_display_name, 'owner', true)
  on conflict (property_id, user_id) do nothing;

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

comment on function public.create_stays_workspace(jsonb) is
  'Creates one short-term-rental workspace and its owner, teams, areas and routes atomically under RLS.';
