-- InnRelay multi-hotel foundation
-- Run once against the InnRelay Supabase project.
-- All browser access remains protected by RLS; no service-role key is used.

begin;

create extension if not exists pg_cron with schema pg_catalog;

-- ---------------------------------------------------------------------------
-- Property identity and owner-created onboarding
-- ---------------------------------------------------------------------------

alter table public.properties
  add column if not exists public_id uuid not null default gen_random_uuid(),
  add column if not exists created_by uuid references auth.users(id) on delete restrict,
  add column if not exists brand_colour text not null default '#ff8a68',
  add column if not exists timezone text not null default 'Europe/London',
  add column if not exists address text,
  add column if not exists guest_welcome text,
  add column if not exists data_retention_days integer not null default 90;

update public.properties property
set created_by = (
  select membership.user_id
  from public.property_staff membership
  where membership.property_id = property.id
    and membership.role = 'owner'
    and membership.active = true
  order by membership.created_at
  limit 1
)
where property.created_by is null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'properties_public_id_key'
      and conrelid = 'public.properties'::regclass
  ) then
    alter table public.properties add constraint properties_public_id_key unique (public_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'properties_brand_colour_check'
      and conrelid = 'public.properties'::regclass
  ) then
    alter table public.properties add constraint properties_brand_colour_check
      check (brand_colour ~ '^#[0-9A-Fa-f]{6}$');
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'properties_data_retention_days_check'
      and conrelid = 'public.properties'::regclass
  ) then
    alter table public.properties add constraint properties_data_retention_days_check
      check (data_retention_days between 30 and 730);
  end if;
end $$;

create or replace function private.is_property_owner(target_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.property_staff membership
    where membership.property_id = target_property_id
      and membership.user_id = (select auth.uid())
      and membership.active = true
      and membership.role = 'owner'
  );
$$;

create or replace function private.can_bootstrap_property_owner(target_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.properties property
    where property.id = target_property_id
      and property.created_by = (select auth.uid())
      and not exists (
        select 1
        from public.property_staff membership
        where membership.property_id = property.id
      )
  );
$$;

create or replace function private.create_property_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_name text;
begin
  owner_name := coalesce(
    nullif((select auth.jwt()->'user_metadata'->>'full_name'), ''),
    nullif((select auth.jwt()->'user_metadata'->>'name'), ''),
    nullif(split_part(coalesce((select auth.jwt()->>'email'), ''), '@', 1), ''),
    'Property owner'
  );

  insert into public.property_staff (property_id, user_id, display_name, role, active)
  values (new.id, new.created_by, left(owner_name, 100), 'owner', true)
  on conflict (property_id, user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists create_property_owner_membership on public.properties;
create trigger create_property_owner_membership
after insert on public.properties
for each row execute function private.create_property_owner_membership();

-- ---------------------------------------------------------------------------
-- Departments, category routing and hotel locations
-- ---------------------------------------------------------------------------

create table if not exists public.property_departments (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  code text not null check (code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  response_target_minutes integer not null default 10 check (response_target_minutes between 1 and 240),
  escalation_minutes integer not null default 20 check (escalation_minutes between 2 and 1440),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code),
  unique (property_id, id)
);

create table if not exists public.property_locations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  department_id uuid,
  public_id uuid not null default gen_random_uuid() unique,
  name text not null check (char_length(name) between 1 and 100),
  code text not null check (char_length(code) between 1 and 80),
  location_type text not null default 'room'
    check (location_type in ('room','reception','bar','restaurant','gym','public_area','other')),
  floor text check (floor is null or char_length(floor) <= 50),
  allows_guest_correction boolean not null default true,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code),
  unique (property_id, id),
  constraint property_locations_department_fkey
    foreign key (property_id, department_id)
    references public.property_departments(property_id, id)
    on delete restrict
);

create table if not exists public.department_routes (
  property_id uuid not null references public.properties(id) on delete cascade,
  category_key text not null check (char_length(category_key) between 1 and 100),
  department_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (property_id, category_key),
  constraint department_routes_department_fkey
    foreign key (property_id, department_id)
    references public.property_departments(property_id, id)
    on delete cascade
);

create index if not exists property_departments_property_active_idx
  on public.property_departments (property_id, active);
create index if not exists property_locations_property_active_sort_idx
  on public.property_locations (property_id, active, sort_order, name);
create index if not exists property_locations_department_idx
  on public.property_locations (department_id) where department_id is not null;
create index if not exists department_routes_department_fkey_idx
  on public.department_routes (property_id, department_id);
create index if not exists property_locations_department_fkey_idx
  on public.property_locations (property_id, department_id) where department_id is not null;
create index if not exists properties_created_by_idx
  on public.properties (created_by) where created_by is not null;

drop trigger if exists set_property_departments_updated_at on public.property_departments;
create trigger set_property_departments_updated_at
before update on public.property_departments
for each row execute function private.set_innrelay_property_updated_at();

drop trigger if exists set_property_locations_updated_at on public.property_locations;
create trigger set_property_locations_updated_at
before update on public.property_locations
for each row execute function private.set_innrelay_property_updated_at();

-- ---------------------------------------------------------------------------
-- Property-scoped invitations and staff departments
-- ---------------------------------------------------------------------------

create table if not exists public.property_invitations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  department_id uuid,
  token uuid not null default gen_random_uuid() unique,
  email text not null check (char_length(email) between 3 and 320),
  role text not null default 'staff' check (role in ('staff','supervisor','manager')),
  active boolean not null default true,
  expires_at timestamptz not null default (now() + interval '7 days'),
  invited_by uuid not null references auth.users(id) on delete restrict,
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint property_invitations_department_fkey
    foreign key (property_id, department_id)
    references public.property_departments(property_id, id)
    on delete restrict
);

alter table public.property_staff
  add column if not exists department_id uuid,
  add column if not exists invite_id uuid references public.property_invitations(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'property_staff_department_fkey'
      and conrelid = 'public.property_staff'::regclass
  ) then
    alter table public.property_staff add constraint property_staff_department_fkey
      foreign key (property_id, department_id)
      references public.property_departments(property_id, id)
      on delete restrict;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'property_staff_invite_id_key'
      and conrelid = 'public.property_staff'::regclass
  ) then
    alter table public.property_staff add constraint property_staff_invite_id_key unique (invite_id);
  end if;
end $$;

create index if not exists property_invitations_property_active_idx
  on public.property_invitations (property_id, active, expires_at);
create index if not exists property_invitations_email_lower_idx
  on public.property_invitations (lower(email));
create index if not exists property_staff_user_active_idx
  on public.property_staff (user_id, active, property_id);
create index if not exists property_invitations_accepted_by_idx
  on public.property_invitations (accepted_by) where accepted_by is not null;
create index if not exists property_invitations_department_fkey_idx
  on public.property_invitations (property_id, department_id) where department_id is not null;
create index if not exists property_invitations_invited_by_idx
  on public.property_invitations (invited_by);
create index if not exists property_staff_department_fkey_idx
  on public.property_staff (property_id, department_id) where department_id is not null;

drop trigger if exists set_property_invitations_updated_at on public.property_invitations;
create trigger set_property_invitations_updated_at
before update on public.property_invitations
for each row execute function private.set_innrelay_property_updated_at();

create or replace function private.accept_property_invitation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation public.property_invitations%rowtype;
  signed_in_email text := lower(coalesce((select auth.jwt()->>'email'), ''));
begin
  if new.invite_id is null then
    return new;
  end if;

  select * into invitation
  from public.property_invitations
  where id = new.invite_id
  for update;

  if invitation.id is null
     or invitation.active is not true
     or invitation.accepted_at is not null
     or invitation.expires_at <= now()
     or lower(invitation.email) <> signed_in_email
     or new.user_id <> (select auth.uid())
     or new.property_id <> invitation.property_id
     or new.role <> invitation.role
     or new.department_id is distinct from invitation.department_id then
    raise exception 'This staff invitation is invalid, expired or belongs to another account.';
  end if;

  update public.property_invitations
  set accepted_by = new.user_id,
      accepted_at = now(),
      active = false,
      updated_at = now()
  where id = invitation.id;

  return new;
end;
$$;

drop trigger if exists accept_property_invitation on public.property_staff;
create trigger accept_property_invitation
before insert on public.property_staff
for each row execute function private.accept_property_invitation();

-- ---------------------------------------------------------------------------
-- QR capability sessions: hotel is locked, location correction stays in hotel
-- ---------------------------------------------------------------------------

create table if not exists public.guest_portal_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  location_id uuid not null,
  property_token uuid not null,
  location_token uuid not null,
  expires_at timestamptz not null default (now() + interval '8 days'),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, property_id, location_id),
  constraint guest_portal_sessions_location_fkey
    foreign key (property_id, location_id)
    references public.property_locations(property_id, id)
    on delete cascade
);

create index if not exists guest_portal_sessions_user_active_idx
  on public.guest_portal_sessions (user_id, expires_at, property_id);
create index if not exists guest_portal_sessions_property_location_idx
  on public.guest_portal_sessions (property_id, location_id, user_id);

create or replace function private.has_guest_portal_access(
  target_property_id uuid,
  target_location_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guest_portal_sessions portal_session
    join public.properties property
      on property.id = portal_session.property_id
     and property.public_id = portal_session.property_token
     and property.active = true
    join public.property_locations location
      on location.id = portal_session.location_id
     and location.property_id = portal_session.property_id
     and location.public_id = portal_session.location_token
     and location.active = true
    where portal_session.user_id = (select auth.uid())
      and portal_session.property_id = target_property_id
      and portal_session.expires_at > now()
      and (target_location_id is null or portal_session.location_id = target_location_id)
  );
$$;

create or replace function private.valid_guest_portal_tokens(
  target_property_id uuid,
  target_location_id uuid,
  supplied_property_token uuid,
  supplied_location_token uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.properties property
    join public.property_locations location
      on location.property_id = property.id
    where property.id = target_property_id
      and property.public_id = supplied_property_token
      and property.active = true
      and location.id = target_location_id
      and location.public_id = supplied_location_token
      and location.active = true
  );
$$;

-- ---------------------------------------------------------------------------
-- Reports gain structured location/department routing, targets and retention
-- ---------------------------------------------------------------------------

alter table public.guest_reports
  add column if not exists location_id uuid,
  add column if not exists department_id uuid,
  add column if not exists acknowledge_due_at timestamptz,
  add column if not exists escalation_due_at timestamptz,
  add column if not exists escalated_at timestamptz,
  add column if not exists retention_delete_after date;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'guest_reports_location_fkey'
      and conrelid = 'public.guest_reports'::regclass
  ) then
    alter table public.guest_reports add constraint guest_reports_location_fkey
      foreign key (property_id, location_id)
      references public.property_locations(property_id, id)
      on delete restrict;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'guest_reports_department_fkey'
      and conrelid = 'public.guest_reports'::regclass
  ) then
    alter table public.guest_reports add constraint guest_reports_department_fkey
      foreign key (property_id, department_id)
      references public.property_departments(property_id, id)
      on delete restrict;
  end if;
end $$;

create index if not exists guest_reports_property_status_created_idx
  on public.guest_reports (property_id, status, created_at desc);
create index if not exists guest_reports_property_department_open_idx
  on public.guest_reports (property_id, department_id, escalation_due_at)
  where status not in ('resolved','closed','cancelled','duplicate');
create index if not exists guest_reports_location_created_idx
  on public.guest_reports (location_id, created_at desc) where location_id is not null;
create index if not exists guest_reports_location_fkey_idx
  on public.guest_reports (property_id, location_id);
create index if not exists guest_reports_guest_created_idx
  on public.guest_reports (guest_user_id, created_at desc) where guest_user_id is not null;

create table if not exists private.guest_submission_events (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  property_id uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists guest_submission_events_limit_idx
  on private.guest_submission_events (user_id, property_id, created_at desc);

create or replace function private.prepare_guest_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_location public.property_locations%rowtype;
  routed_department uuid;
  response_minutes integer := 10;
  escalation_minutes integer := 20;
  retention_days integer := 90;
  recent_submissions integer;
begin
  if new.location_id is not null then
    select * into selected_location
    from public.property_locations
    where id = new.location_id
      and property_id = new.property_id
      and active = true;

    if selected_location.id is null then
      raise exception 'The selected hotel location is unavailable.';
    end if;

    new.location := selected_location.name;
  end if;

  select route.department_id into routed_department
  from public.department_routes route
  where route.property_id = new.property_id
    and route.category_key = new.category_key;

  new.department_id := coalesce(routed_department, selected_location.department_id, new.department_id);

  if new.department_id is not null then
    select department.response_target_minutes, department.escalation_minutes
    into response_minutes, escalation_minutes
    from public.property_departments department
    where department.id = new.department_id
      and department.property_id = new.property_id
      and department.active = true;
  end if;

  select property.data_retention_days into retention_days
  from public.properties property
  where property.id = new.property_id;

  new.acknowledge_due_at := coalesce(new.acknowledge_due_at, now() + make_interval(mins => response_minutes));
  new.escalation_due_at := coalesce(new.escalation_due_at, now() + make_interval(mins => escalation_minutes));
  new.retention_delete_after := coalesce(new.retention_delete_after, (current_date + retention_days));

  if new.source = 'guest' then
    if new.guest_user_id <> (select auth.uid())
       or new.location_id is null
       or not private.has_guest_portal_access(new.property_id, new.location_id) then
      raise exception 'Scan a valid InnRelay hotel QR code before submitting a request.';
    end if;

    select count(*) into recent_submissions
    from private.guest_submission_events submission
    where submission.user_id = (select auth.uid())
      and submission.property_id = new.property_id
      and submission.created_at > now() - interval '10 minutes';

    if recent_submissions >= 8 then
      raise exception 'Too many requests were sent. Please wait a few minutes or call Reception.';
    end if;

    insert into private.guest_submission_events (user_id, property_id)
    values ((select auth.uid()), new.property_id);
  end if;

  return new;
end;
$$;

drop trigger if exists prepare_guest_report on public.guest_reports;
create trigger prepare_guest_report
before insert on public.guest_reports
for each row execute function private.prepare_guest_report();

create or replace function private.validate_guest_report_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  assigned_display_name text;
begin
  if new.owner_user_id is null then
    new.owner_display := null;
    return new;
  end if;

  select membership.display_name
  into assigned_display_name
  from public.property_staff membership
  where membership.property_id = new.property_id
    and membership.user_id = new.owner_user_id
    and membership.active = true;

  if assigned_display_name is null then
    raise exception 'The selected assignee is not active staff for this property.';
  end if;

  new.owner_display := assigned_display_name;
  return new;
end;
$$;

drop trigger if exists validate_guest_report_owner on public.guest_reports;
create trigger validate_guest_report_owner
before insert or update of owner_user_id, property_id on public.guest_reports
for each row execute function private.validate_guest_report_owner();

create or replace function private.mark_overdue_guest_reports()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_rows integer;
begin
  update public.guest_reports
  set escalated_at = now()
  where status = 'reported'
    and acknowledged_at is null
    and escalation_due_at is not null
    and escalation_due_at <= now()
    and escalated_at is null;

  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- Seed the pilot property with useful departments and locations
-- ---------------------------------------------------------------------------

insert into public.property_departments (property_id, name, code, response_target_minutes, escalation_minutes)
select property.id, seed.name, seed.code, seed.response_target, seed.escalation
from public.properties property
cross join (values
  ('Reception', 'reception', 5, 10),
  ('Housekeeping', 'housekeeping', 10, 20),
  ('Maintenance', 'maintenance', 10, 25),
  ('Food & Beverage', 'food-beverage', 10, 20),
  ('Duty Management', 'duty-management', 5, 10)
) as seed(name, code, response_target, escalation)
where property.slug = 'exhibition-court'
on conflict (property_id, code) do nothing;

with route_map(category_key, department_code) as (
  values
    ('housekeeping-cleanliness', 'housekeeping'),
    ('linen-towels-toiletries', 'housekeeping'),
    ('laundry-dry-cleaning', 'housekeeping'),
    ('pest-hygiene-environment', 'housekeeping'),
    ('bathroom-plumbing', 'maintenance'),
    ('heating-cooling-air', 'maintenance'),
    ('electrical-lighting', 'maintenance'),
    ('room-furniture-fixtures', 'maintenance'),
    ('wifi-tv-phone-technology', 'maintenance'),
    ('public-areas-lifts', 'maintenance'),
    ('accessibility-mobility', 'maintenance'),
    ('spa-gym-pool-leisure', 'maintenance'),
    ('outdoor-grounds-smoking', 'maintenance'),
    ('sustainability-waste', 'maintenance'),
    ('building-maintenance', 'maintenance'),
    ('hotel-systems-it', 'maintenance'),
    ('breakfast', 'food-beverage'),
    ('restaurant-room-service', 'food-beverage'),
    ('bar-beverages', 'food-beverage'),
    ('food-allergy-dietary-safety', 'food-beverage'),
    ('minibar-vending-retail', 'food-beverage'),
    ('kitchen-food-operations', 'food-beverage'),
    ('stock-supplies', 'food-beverage'),
    ('medical-safety-emergency', 'duty-management'),
    ('fire-life-safety-compliance', 'duty-management'),
    ('security-incident', 'duty-management'),
    ('staffing-operations', 'duty-management'),
    ('cash-pos-financial', 'duty-management'),
    ('doors-keys-security', 'reception'),
    ('noise-disturbance', 'reception'),
    ('reception-reservations-checkin', 'reception'),
    ('billing-payments-refunds', 'reception'),
    ('guest-service-requests', 'reception'),
    ('parking-arrival-transport', 'reception'),
    ('family-children', 'reception'),
    ('pets-assistance-animals', 'reception'),
    ('lost-property-deliveries', 'reception'),
    ('meetings-events-business', 'reception'),
    ('staff-service-recovery', 'reception')
)
insert into public.department_routes (property_id, category_key, department_id)
select property.id, route_map.category_key, department.id
from public.properties property
join route_map on true
join public.property_departments department
  on department.property_id = property.id
 and department.code = route_map.department_code
where property.active = true
on conflict (property_id, category_key)
do update set department_id = excluded.department_id;

insert into public.property_locations
  (property_id, department_id, name, code, location_type, floor, sort_order)
select property.id, department.id, seed.name, seed.code, seed.location_type, seed.floor, seed.sort_order
from public.properties property
join (values
  ('Room 208', '208', 'room', '2', 'housekeeping', 10),
  ('Reception', 'reception', 'reception', 'Ground', 'reception', 20),
  ('Bar', 'bar', 'bar', 'Ground', 'food-beverage', 30),
  ('Restaurant', 'restaurant', 'restaurant', 'Ground', 'food-beverage', 40),
  ('Gym', 'gym', 'gym', 'Ground', 'maintenance', 50),
  ('Lobby & public areas', 'public-areas', 'public_area', 'Ground', 'reception', 60)
) as seed(name, code, location_type, floor, department_code, sort_order) on true
join public.property_departments department
  on department.property_id = property.id
 and department.code = seed.department_code
where property.slug = 'exhibition-court'
on conflict (property_id, code) do nothing;

update public.guest_reports report
set location_id = location.id,
    department_id = coalesce(report.department_id, location.department_id)
from public.property_locations location
where report.location_id is null
  and location.property_id = report.property_id
  and lower(location.name) = lower(report.location);

-- ---------------------------------------------------------------------------
-- RLS: every staff query is membership-scoped; guests need a valid QR session
-- ---------------------------------------------------------------------------

alter table public.property_departments enable row level security;
alter table public.property_locations enable row level security;
alter table public.department_routes enable row level security;
alter table public.property_invitations enable row level security;
alter table public.guest_portal_sessions enable row level security;

drop policy if exists "Authenticated users can view active properties" on public.properties;
drop policy if exists "Managers can update their property" on public.properties;
drop policy if exists "Staff or portal guests can view properties" on public.properties;
drop policy if exists "Signed-in users can create properties" on public.properties;
drop policy if exists "Managers can update their property" on public.properties;
drop policy if exists "Owners can delete their property" on public.properties;

create policy "Staff or portal guests can view properties"
on public.properties for select to authenticated
using (private.is_property_staff(id) or private.has_guest_portal_access(id));

create policy "Signed-in users can create properties"
on public.properties for insert to authenticated
with check (created_by = (select auth.uid()));

create policy "Managers can update their property"
on public.properties for update to authenticated
using (private.is_property_manager(id))
with check (private.is_property_manager(id));

create policy "Owners can delete their property"
on public.properties for delete to authenticated
using (private.is_property_owner(id));

drop policy if exists "Staff can view relevant memberships" on public.property_staff;
drop policy if exists "Property staff can view team memberships" on public.property_staff;
drop policy if exists "Managers can add property staff" on public.property_staff;
drop policy if exists "Managers can update property staff" on public.property_staff;
drop policy if exists "Managers can remove property staff" on public.property_staff;

create policy "Property staff can view team memberships"
on public.property_staff for select to authenticated
using (private.is_property_staff(property_id));

create policy "Owners managers and invitees can add memberships"
on public.property_staff for insert to authenticated
with check (
  (
    private.is_property_manager(property_id)
    and (role <> 'owner' or private.is_property_owner(property_id))
  )
  or (
    user_id = (select auth.uid())
    and role = 'owner'
    and invite_id is null
    and private.can_bootstrap_property_owner(property_id)
  )
  or (
    user_id = (select auth.uid())
    and invite_id is not null
    and exists (
      select 1 from public.property_invitations invitation
      where invitation.id = invite_id
        and invitation.property_id = property_id
        and invitation.department_id is not distinct from department_id
        and invitation.role = role
        and invitation.active = true
        and invitation.accepted_at is null
        and invitation.expires_at > now()
        and lower(invitation.email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
    )
  )
);

create policy "Managers can update non-owner memberships"
on public.property_staff for update to authenticated
using (private.is_property_manager(property_id) and (role <> 'owner' or private.is_property_owner(property_id)))
with check (private.is_property_manager(property_id) and (role <> 'owner' or private.is_property_owner(property_id)));

create policy "Managers can remove non-owner memberships"
on public.property_staff for delete to authenticated
using (private.is_property_manager(property_id) and (role <> 'owner' or private.is_property_owner(property_id)));

create policy "Property staff can view departments"
on public.property_departments for select to authenticated
using (private.is_property_staff(property_id));
create policy "Managers can add departments"
on public.property_departments for insert to authenticated
with check (private.is_property_manager(property_id));
create policy "Managers can update departments"
on public.property_departments for update to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));
create policy "Managers can remove departments"
on public.property_departments for delete to authenticated
using (private.is_property_manager(property_id));

create policy "Staff and locked guests can view locations"
on public.property_locations for select to authenticated
using (private.is_property_staff(property_id) or private.has_guest_portal_access(property_id));
create policy "Managers can add locations"
on public.property_locations for insert to authenticated
with check (private.is_property_manager(property_id));
create policy "Managers can update locations"
on public.property_locations for update to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));
create policy "Managers can remove locations"
on public.property_locations for delete to authenticated
using (private.is_property_manager(property_id));

create policy "Property staff can view routes"
on public.department_routes for select to authenticated
using (private.is_property_staff(property_id));
create policy "Managers can add routes"
on public.department_routes for insert to authenticated
with check (private.is_property_manager(property_id));
create policy "Managers can update routes"
on public.department_routes for update to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));
create policy "Managers can remove routes"
on public.department_routes for delete to authenticated
using (private.is_property_manager(property_id));

create policy "Managers and recipients can view invitations"
on public.property_invitations for select to authenticated
using (
  private.is_property_manager(property_id)
  or lower(email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
);
create policy "Managers can create invitations"
on public.property_invitations for insert to authenticated
with check (private.is_property_manager(property_id) and invited_by = (select auth.uid()));
create policy "Managers can update invitations"
on public.property_invitations for update to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));
create policy "Managers can delete invitations"
on public.property_invitations for delete to authenticated
using (private.is_property_manager(property_id));

create policy "Guests can view their portal sessions"
on public.guest_portal_sessions for select to authenticated
using (user_id = (select auth.uid()));
create policy "Guests can claim a valid QR portal"
on public.guest_portal_sessions for insert to authenticated
with check (
  user_id = (select auth.uid())
  and expires_at > now()
  and expires_at <= now() + interval '14 days'
  and private.valid_guest_portal_tokens(property_id, location_id, property_token, location_token)
);
create policy "Guests can refresh their portal sessions"
on public.guest_portal_sessions for update to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and private.valid_guest_portal_tokens(property_id, location_id, property_token, location_token)
);
create policy "Guests can remove their portal sessions"
on public.guest_portal_sessions for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Guests or staff can create permitted reports" on public.guest_reports;
create policy "Guests or staff can create permitted reports"
on public.guest_reports for insert to authenticated
with check (
  (
    guest_user_id = (select auth.uid())
    and source = 'guest'
    and status = 'reported'
    and owner_user_id is null
    and owner_display is null
    and staff_note is null
    and resolution_note is null
    and acknowledged_at is null
    and resolved_at is null
    and location_id is not null
    and private.has_guest_portal_access(property_id, location_id)
  )
  or private.is_property_staff(property_id)
);

-- ---------------------------------------------------------------------------
-- Least-privilege API grants (anonymous browser role gets no table access)
-- ---------------------------------------------------------------------------

revoke all on table public.properties from anon, authenticated;
revoke all on table public.property_staff from anon, authenticated;
revoke all on table public.property_departments from anon, authenticated;
revoke all on table public.property_locations from anon, authenticated;
revoke all on table public.department_routes from anon, authenticated;
revoke all on table public.property_invitations from anon, authenticated;
revoke all on table public.guest_portal_sessions from anon, authenticated;
revoke all on table public.guest_reports from anon, authenticated;
revoke all on table public.guest_report_updates from anon, authenticated;

grant select, insert, update, delete on table public.properties to authenticated;
grant select, insert, update, delete on table public.property_staff to authenticated;
grant select, insert, update, delete on table public.property_departments to authenticated;
grant select, insert, update, delete on table public.property_locations to authenticated;
grant select, insert, update, delete on table public.department_routes to authenticated;
grant select, insert, update, delete on table public.property_invitations to authenticated;
grant select, insert, update, delete on table public.guest_portal_sessions to authenticated;
grant select, insert, update, delete on table public.guest_reports to authenticated;
grant select, insert on table public.guest_report_updates to authenticated;

revoke all on all functions in schema private from public, anon;
grant execute on function private.is_property_staff(uuid) to authenticated;
grant execute on function private.is_property_manager(uuid) to authenticated;
grant execute on function private.is_property_owner(uuid) to authenticated;
grant execute on function private.can_bootstrap_property_owner(uuid) to authenticated;
grant execute on function private.has_guest_portal_access(uuid, uuid) to authenticated;
grant execute on function private.valid_guest_portal_tokens(uuid, uuid, uuid, uuid) to authenticated;

select cron.schedule(
  'innrelay-mark-overdue-guest-reports',
  '* * * * *',
  'select private.mark_overdue_guest_reports();'
);

-- Realtime publication for new multi-hotel configuration tables.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'property_locations'
  ) then
    alter publication supabase_realtime add table public.property_locations;
  end if;
end $$;

commit;
