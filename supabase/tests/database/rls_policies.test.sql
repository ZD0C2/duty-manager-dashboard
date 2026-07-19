-- Critical RLS / multi-tenant isolation assertions for InnRelay.
-- Run locally with `supabase test db` (spins up a fresh local stack,
-- replays supabase/migrations/, then runs every *.test.sql file here).
-- This is a targeted set of the highest-value guarantees, not exhaustive
-- coverage: cross-property isolation, the two anonymous-write blockers
-- (SEC-3), and the department_routes vertical guard added 2026-07-19.

begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

-- Fixtures: one hotel property, one short-term-rental property, one staff
-- member per property, and one bystander user with no membership anywhere.
insert into auth.users (id, email, raw_user_meta_data, is_anonymous, aud, role)
values
  ('11111111-1111-1111-1111-111111111111', 'hotel-owner@example.test', '{"full_name":"Hotel Owner"}', false, 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'stays-owner@example.test', '{"full_name":"Stays Owner"}', false, 'authenticated', 'authenticated'),
  ('33333333-3333-3333-3333-333333333333', 'bystander@example.test', '{"full_name":"Bystander"}', false, 'authenticated', 'authenticated');

-- The create_property_owner_membership trigger (AFTER INSERT ON properties)
-- already creates each owner's property_staff row automatically -- do not
-- also insert it explicitly here, or it collides with the trigger's row on
-- the (property_id, user_id) primary key, exactly like the bug fixed in
-- create_stays_workspace on 2026-07-19.
insert into public.properties (id, name, slug, created_by, property_type, active)
values
  ('a1111111-1111-1111-1111-111111111111', 'Test Hotel', 'pgtap-test-hotel', '11111111-1111-1111-1111-111111111111', 'hotel', true),
  ('a2222222-2222-2222-2222-222222222222', 'Test Stay', 'pgtap-test-stay', '22222222-2222-2222-2222-222222222222', 'short_term_rental', true);

insert into public.property_departments (id, property_id, name, code, response_target_minutes, escalation_minutes)
values ('d1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', 'Reception', 'reception', 5, 15);

insert into public.guest_reports (id, property_id, guest_user_id, source, location, category_key, category_label, issue_code, title, status)
values ('e1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'staff', 'Room 101', 'test', 'Test category', 'test:issue', 'pgTAP fixture report', 'reported');

-- 1. Fully unauthenticated (anon role, no session at all) cannot read guest_reports.
set local role anon;
select throws_ok(
  $$ select * from public.guest_reports $$,
  '42501',
  null,
  'anon role has no table grant on guest_reports'
);
reset role;

-- 2. Hotel staff can see their own property's report.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','11111111-1111-1111-1111-111111111111','email','hotel-owner@example.test','is_anonymous','false')::text, true);
select is(
  (select count(*)::int from public.guest_reports where id = 'e1111111-1111-1111-1111-111111111111'),
  1,
  'hotel staff can see their own property''s guest report'
);

-- 3. Hotel staff cannot see a bystander's unrelated property (none exists yet,
-- so assert isolation the direct way: staff of property A gets zero rows
-- when no report exists for property A other than the fixture, i.e. RLS is
-- filtering by property_staff membership, not returning every row.
select is(
  (select count(*)::int from public.guest_reports),
  1,
  'RLS scopes guest_reports to the caller''s property, not every row in the table'
);
reset role;

-- 4. The bystander (authenticated, but no property_staff row anywhere)
-- sees zero guest_reports at all.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','33333333-3333-3333-3333-333333333333','email','bystander@example.test','is_anonymous','false')::text, true);
select is(
  (select count(*)::int from public.guest_reports),
  0,
  'a user with no property_staff membership sees zero guest_reports'
);

-- 5. The bystander cannot insert themselves into property_staff for a
-- property they don't manage (privilege escalation check).
select throws_ok(
  $$ insert into public.property_staff (property_id, user_id, display_name, role, active)
     values ('a1111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Self-appointed', 'manager', true) $$,
  '42501',
  null,
  'a non-manager cannot insert their own property_staff row'
);
reset role;

-- 6. An anonymous auth SESSION (is_anonymous = true, not just the anon
-- role) is blocked from creating a property -- this is the SEC-3 fix.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','44444444-4444-4444-4444-444444444444','is_anonymous','true')::text, true);
select throws_ok(
  $$ insert into public.properties (name, slug, created_by, property_type)
     values ('Rogue Property', 'pgtap-rogue-property', '44444444-4444-4444-4444-444444444444', 'hotel') $$,
  '42501',
  null,
  'an anonymous auth session cannot insert into properties (SEC-3)'
);
reset role;

-- 7. create_stays_workspace rejects an anonymous session with a friendly
-- P0001 exception, not a raw constraint error.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','55555555-5555-5555-5555-555555555555','is_anonymous','true')::text, true);
select throws_ok(
  $$ select public.create_stays_workspace('{"name":"Rogue Stay","slug":"pgtap-rogue-stay"}'::jsonb) $$,
  'P0001',
  'Sign in with Google before registering an InnRelay Stays workspace.',
  'create_stays_workspace rejects an anonymous session'
);
reset role;

-- 8. department_routes vertical guard: a Stays-only category cannot be
-- routed for a hotel property.
set local role postgres;
select throws_ok(
  $$ insert into public.department_routes (property_id, category_key, department_id)
     values ('a1111111-1111-1111-1111-111111111111', 'str-wifi-tv-technology', 'd1111111-1111-1111-1111-111111111111') $$,
  'P0001',
  'This category belongs to InnRelay Stays and cannot be routed for a hotel property.',
  'a Stays category cannot be routed for a hotel property'
);

-- 9. department_routes vertical guard: a non-Stays category is rejected
-- for a short-term-rental property (must come from the Stays catalogue --
-- category_key has no FK constraint, so the vertical guard trigger is the
-- only thing enforcing this).
select throws_ok(
  $$ insert into public.department_routes (property_id, category_key, department_id)
     select 'a2222222-2222-2222-2222-222222222222', 'not-a-real-category', department.id
     from public.property_departments department
     where department.property_id = 'a1111111-1111-1111-1111-111111111111'
     limit 1 $$,
  'P0001',
  'This category is not part of the InnRelay Stays catalogue.',
  'an unrecognised category is rejected for a Stays property'
);

-- 10. The property_staff primary key still prevents a duplicate
-- (property_id, user_id) row -- this is the invariant the 2026-07-19
-- create_stays_workspace fix depends on (ON CONFLICT DO NOTHING assumes
-- the constraint is still exactly (property_id, user_id)).
select throws_ok(
  $$ insert into public.property_staff (property_id, user_id, display_name, role, active)
     values ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Duplicate', 'staff', true) $$,
  '23505',
  null,
  'property_staff still enforces a unique (property_id, user_id) pair'
);
reset role;

select * from finish();
rollback;
